package com.github.tfox.flutter_vless.xray.core

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class TrafficSamplerTest {
    @Test fun delayedStatsAndProbeTimeDoNotInflateRates() {
        val sampler = TrafficSampler()
        sampler.reset(0)
        assertArrayEquals(longArrayOf(1000, 2000, 1000, 2000), sampler.sample(1000, 2000, 1_000_000_000))
        assertArrayEquals(longArrayOf(1000, 2000, 5000, 10000), sampler.sample(5000, 10000, 5_000_000_000))
    }
    @Test fun restartedCountersAndZeroIntervalNeverGiveNegativeRates() {
        val sampler = TrafficSampler()
        sampler.reset(0)
        sampler.sample(1000, 2000, 1_000_000_000)
        assertArrayEquals(longArrayOf(0, 0, 0, 0), sampler.sample(0, 0, 2_000_000_000))
        sampler.reset(3_000_000_000)
        assertArrayEquals(longArrayOf(0, 0, 100, 200), sampler.sample(100, 200, 3_000_000_000))
    }
}
