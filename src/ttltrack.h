#ifndef _TTLTRACK_H
#define _TTLTRACK_H
#include <stdint.h>
#include "dnsredir.h"

// TCP connection tracking information
typedef struct tcp_conntrack_info {
    uint8_t  is_ipv6;      // Flag indicating if IPv6 (1) or IPv4 (0)
    uint8_t  ttl;          // Time-to-live value of the connection
    uint32_t srcip[4];     // Source IP address (supports both IPv4 and IPv6)
    uint16_t srcport;      // Source port
    uint32_t dstip[4];     // Destination IP address (supports both IPv4 and IPv6)
    uint16_t dstport;      // Destination port
} tcp_conntrack_info_t;

// Process incoming TCP SYN/ACK packets to extract TTL values
int tcp_handle_incoming(uint32_t srcip[4], uint32_t dstip[4],
                        uint16_t srcport, uint16_t dstport,
                        uint8_t is_ipv6, uint8_t ttl);

// Process outgoing TCP packets and match with stored connections
int tcp_handle_outgoing(uint32_t srcip[4], uint32_t dstip[4],
                        uint16_t srcport, uint16_t dstport,
                        tcp_conntrack_info_t *conn_info,
                        uint8_t is_ipv6);

// Calculate appropriate TTL value for packet fragmentation evasion
int tcp_get_auto_ttl(const uint8_t ttl, const uint8_t autottl1,
                     const uint8_t autottl2, const uint8_t minhops,
                     const uint8_t maxttl);
#endif
