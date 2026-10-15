package com.github.tfox.flutter_vless.xray.core

import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSession

class LegacyTlsVerificationTest {
    @Test fun oldPlatformStillRequiresHostnameVerificationAfterHandshake() {
        val socket = mock(SSLSocket::class.java)
        val session = mock(SSLSession::class.java)
        `when`(socket.session).thenReturn(session)
        val verifier = mock(HostnameVerifier::class.java)
        `when`(verifier.verify("dns.example", session)).thenReturn(true)
        AuthenticatedSocksClient.startVerifiedTls(socket, "dns.example", verifier)
        val order = inOrder(socket, verifier)
        order.verify(socket).startHandshake()
        order.verify(socket).session
        order.verify(verifier).verify("dns.example", session)
        verify(socket, never()).close()
    }
    @Test fun wrongHostClosesTlsInsteadOfSendingARequest() {
        val socket = mock(SSLSocket::class.java)
        `when`(socket.session).thenReturn(mock(SSLSession::class.java))
        val verifier = mock(HostnameVerifier::class.java)
        try {
            AuthenticatedSocksClient.startVerifiedTls(socket, "dns.example", verifier)
            fail("Unverified TLS must fail closed")
        } catch (_: SSLPeerUnverifiedException) { }
        verify(socket).close()
    }
}
