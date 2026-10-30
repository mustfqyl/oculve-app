import tempfile
import unittest
from pathlib import Path

from .core import (
    ALLOWED_SNI, AUTO_GROUP_IDS, AUTO_GROUP_PROFILES, AUTO_LADDER_GROUPS, BLOCKED_SNI,
    MINIMUM_LEARNED_RESPONSES, MODES, PROFILES, STAT_LIMIT, GroupCounters, Unavailable,
    auto_group_order, auto_ladder_args, best_group, outcome, run_matrix,
)

SPLIT_PROFILES = ("split 1+s", "disorder 1+s", "split 1+s, disorder 3+s")
# Fixed rows in the order engine profile 4 tries its groups.
AUTO_LADDER_ORDER = tuple(AUTO_GROUP_PROFILES[group] for group in AUTO_GROUP_IDS)
AUTO_LADDER = "auto ladder (profile 4)"
LEARNED_FIRST_LADDER = "auto ladder, learned first (profile 4)"


def _cells(result):
    return [(cell["profile"], cell["mode"], cell["sni"], cell["outcome"]) for cell in result["cells"]]


def _walk(result, mode, first_group=0, connections=3):
    """One automatic connection per step: the chain stops at the first group that passes."""
    counters = GroupCounters(first_group)
    for _ in range(connections):
        for group in counters.order:
            if outcome(result, AUTO_GROUP_PROFILES[group], mode) == "PASS":
                counters.note_ok(group)
                break
            counters.note_fail(group)
        else:
            counters.note_exhausted()
    return counters


class DpiGroupOrderTest(unittest.TestCase):
    def test_requested_group_runs_first_and_every_group_runs_once(self):
        for first in range(len(AUTO_GROUP_IDS)):
            with self.subTest(first_group=first):
                order = auto_group_order(first)
                self.assertEqual(order[0], first + 1)
                self.assertEqual(sorted(order), AUTO_GROUP_IDS)

    def test_out_of_range_first_group_keeps_the_builtin_order(self):
        for first in (-1, -7, len(AUTO_GROUP_IDS), 99):
            with self.subTest(first_group=first):
                self.assertEqual(auto_group_order(first), AUTO_GROUP_IDS)

    def test_rotation_only_reorders_the_same_chain(self):
        builtin = auto_ladder_args()
        self.assertEqual(builtin, auto_ladder_args(0))
        self.assertEqual(builtin.count("--auto"), len(AUTO_GROUP_IDS))
        for first in range(len(AUTO_GROUP_IDS)):
            rotated = auto_ladder_args(first)
            with self.subTest(first_group=first):
                self.assertEqual(sorted(rotated), sorted(builtin))
                start = rotated.index("--auto") + 2
                group = AUTO_LADDER_GROUPS[first]
                self.assertEqual(rotated[start:start + len(group)], group)


class DpiGroupCountersTest(unittest.TestCase):
    def test_unknown_group_ids_are_ignored(self):
        counters = GroupCounters()
        for group in (-1, len(AUTO_GROUP_IDS) + 1, 99):
            counters.note_ok(group)
            counters.note_fail(group)
        self.assertEqual(counters.stats(), [(group, 0, 0) for group in AUTO_GROUP_IDS])

    def test_counters_stop_at_the_stat_limit(self):
        counters = GroupCounters()
        counters.ok[2] = counters.fail[2] = STAT_LIMIT
        counters.exhausted = STAT_LIMIT
        counters.note_ok(2)
        counters.note_fail(2)
        counters.note_exhausted()
        self.assertEqual(counters.stats()[1], (2, STAT_LIMIT, STAT_LIMIT))
        self.assertEqual(counters.exhausted, STAT_LIMIT)

    def test_stats_keep_preset_order_under_rotation(self):
        # A learned group only rotates the chain; the reported ids stay stable.
        counters = GroupCounters(first_group=3)
        self.assertEqual(counters.order, [4, 5, 1, 2, 3])
        counters.note_ok(4)
        counters.note_ok(1)
        self.assertEqual(counters.stats(), [(1, 1, 0), (2, 0, 0), (3, 0, 0), (4, 1, 0), (5, 0, 0)])


class DpiLearnerPolicyTest(unittest.TestCase):
    def test_a_single_probe_is_not_evidence(self):
        self.assertIsNone(best_group([]))
        self.assertIsNone(best_group([(1, MINIMUM_LEARNED_RESPONSES - 1, 0)]))
        self.assertEqual(best_group([(1, MINIMUM_LEARNED_RESPONSES, 0)]), 1)

    def test_best_ratio_wins(self):
        self.assertEqual(best_group([(1, 6, 2), (2, 3, 0)]), 2)  # 2.0 vs 3.0
        self.assertEqual(best_group([(1, 3, 0), (2, 3, 5)]), 1)  # 3.0 vs 0.5

    def test_equal_ratio_and_count_prefer_the_earlier_preset(self):
        self.assertEqual(best_group([(3, 3, 0), (1, 3, 0)]), 1)

    def test_untried_groups_never_win(self):
        self.assertIsNone(best_group([(group, 0, 0) for group in AUTO_GROUP_IDS]))


class DpiSimMatrixTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory(prefix="oculve-dpi-sim-")
        try:
            cls.result = run_matrix(Path(cls.work.name))
        except Unavailable as error:
            cls.work.cleanup()
            raise unittest.SkipTest(str(error))

    @classmethod
    def tearDownClass(cls):
        cls.work.cleanup()

    def test_no_cell_is_an_error(self):
        # ERROR means the harness or ciadpi broke, not that the filter blocked anything.
        errors = [cell for cell in self.result["cells"] if cell["outcome"] == "ERROR"]
        self.assertEqual(errors, [])

    def test_bypass_less_blocked_sni_fails_in_every_mode(self):
        for mode in MODES:
            with self.subTest(mode=mode):
                self.assertEqual(outcome(self.result, "direct", mode), "BLOCKED")

    def test_control_sni_passes_with_every_profile(self):
        for profile in PROFILES:
            for mode in MODES:
                with self.subTest(profile=profile, mode=mode):
                    self.assertEqual(outcome(self.result, profile, mode, ALLOWED_SNI), "PASS")

    def test_stateless_filter_is_passed_by_a_split_profile(self):
        self.assertTrue(any(outcome(self.result, p, "stateless") == "PASS" for p in SPLIT_PROFILES))

    def test_tlsrec_passes_stateless_and_record_filters_but_not_stateful(self):
        for mode in ("stateless", "record"):
            self.assertEqual(outcome(self.result, "tlsrec 1+s", mode), "PASS", mode)
        self.assertEqual(outcome(self.result, "tlsrec 1+s", "stateful"), "BLOCKED")

    def test_stateful_filter_blocks_every_profile(self):
        for profile in PROFILES:
            with self.subTest(profile=profile):
                self.assertEqual(outcome(self.result, profile, "stateful"), "BLOCKED")

    def test_auto_ladder_reaches_the_same_verdict_as_its_groups(self):
        # The real ciadpi auto chain must pass wherever some fixed group passes.
        for mode in MODES:
            with self.subTest(mode=mode):
                passes = any(outcome(self.result, p, mode) == "PASS" for p in AUTO_LADDER_ORDER)
                self.assertEqual(outcome(self.result, AUTO_LADDER, mode), "PASS" if passes else "BLOCKED")

    def test_first_passing_ladder_group_needs_at_most_two_attempts(self):
        # Attempt number = 1-based index of the first group that passes in this mode.
        for mode in MODES:
            with self.subTest(mode=mode):
                passing = [i for i, p in enumerate(AUTO_LADDER_ORDER) if outcome(self.result, p, mode) == "PASS"]
                if passing:
                    self.assertLessEqual(passing[0] + 1, 2)

    def test_matrix_is_deterministic(self):
        with tempfile.TemporaryDirectory(prefix="oculve-dpi-sim-") as work:
            again = run_matrix(Path(work))
        self.assertEqual(_cells(again), _cells(self.result))

    def test_learned_first_ladder_keeps_the_builtin_verdicts(self):
        for mode in MODES:
            with self.subTest(mode=mode):
                self.assertEqual(outcome(self.result, LEARNED_FIRST_LADDER, mode),
                                 outcome(self.result, AUTO_LADDER, mode))

    def test_learning_picks_the_group_that_carried_traffic_and_tries_it_first(self):
        for mode in ("stateless", "record"):
            with self.subTest(mode=mode):
                counters = _walk(self.result, mode)
                learned = best_group(counters.stats())
                first_passing = next(group for group in AUTO_GROUP_IDS
                                     if outcome(self.result, AUTO_GROUP_PROFILES[group], mode) == "PASS")
                self.assertEqual(learned, first_passing)
                self.assertEqual(counters.exhausted, 0)
                # The learned value is a preset index, so the next start runs it first.
                self.assertEqual(auto_group_order(learned - 1)[0], learned)

    def test_a_network_that_blocks_every_group_reports_exhausted(self):
        counters = _walk(self.result, "stateful")
        self.assertEqual(counters.exhausted, 3)
        self.assertIsNone(best_group(counters.stats()))
