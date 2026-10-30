"""Discovered by `python3 -m unittest discover -s test -p '*_test.py'`.

The offline DPI simulator and its ciadpi profile matrix live in test/dpi_sim/.
The group-order, counter and learner tests need no host tool, so they always
run; the matrix skips itself when cc/make/openssl/curl are missing.
"""

from dpi_sim.test_dpi_sim import (  # noqa: F401
    DpiGroupCountersTest,
    DpiGroupOrderTest,
    DpiLearnerPolicyTest,
    DpiSimMatrixTest,
)
