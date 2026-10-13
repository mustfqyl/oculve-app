package com.github.tfox.flutter_vless.xray.core

import org.junit.Assert.*
import org.junit.Test

class ProtectedEndpointDnsTest {
    private val response = """{"Status":0,"Question":[{"name":"vpn.example.","type":1}],"Answer":[{"name":"vpn.example.","type":5,"data":"edge.example."},{"name":"edge.example.","type":1,"data":"192.0.2.17"},{"name":"unrelated.example.","type":1,"data":"198.51.100.1"}]}"""
    @Test fun acceptsOnlyAddressesInTheRequestedAliasChain() {
        assertEquals(listOf("192.0.2.17"), AuthenticatedSocksClient.parseDnsJson(response, "VPN.EXAMPLE"))
    }
    @Test fun rejectsWrongQuestionTruncationAndDnsFailure() {
        for (body in listOf(response.replace("\"Status\":0", "\"Status\":2"),
            response.replace("\"Status\":0", "\"Status\":0,\"TC\":true"))) {
            try { AuthenticatedSocksClient.parseDnsJson(body, "vpn.example"); fail("Untrusted DNS result accepted") } catch (_: IllegalArgumentException) { }
        }
        try { AuthenticatedSocksClient.parseDnsJson(response, "another.example"); fail("Wrong question accepted") } catch (_: IllegalArgumentException) { }
    }
}
