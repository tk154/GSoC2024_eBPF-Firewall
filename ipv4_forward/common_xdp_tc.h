#ifndef COMMON_XDP_TC_H
#define COMMON_XDP_TC_H

#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

#if defined(XDP_PROGRAM)
/* XDP program */
#define BPF_PASS        XDP_PASS            // Let the package pass to the normal network stack
#define BPF_DROP        XDP_DROP            // Drop the package
#define BPF_REDIRECT    XDP_REDIRECT        // Redirect the package to another network interface

/* user accessible metadata for XDP packet hook
 * new fields must be added to the end of this structure
 */
#define BPF_CTX         xdp_md

#elif defined(TC_PROGRAM)
/* TC program */
#include <linux/pkt_cls.h>

#define BPF_PASS        TC_ACT_UNSPEC       // Let the package pass to the normal network stack
#define BPF_DROP        TC_ACT_SHOT         // Drop the package
#define BPF_REDIRECT    TC_ACT_REDIRECT     // Redirect the package to another network interface

/* user accessible mirror of in-kernel sk_buff.
 * new fields can only be added to the end of this structure
 */
#define BPF_CTX         __sk_buff
#endif

#ifndef memcpy
#define memcpy(dest, src, n) __builtin_memcpy(dest, src, n)
#endif

#if DEBUG
#define BPF_DEBUG(fmt, args...) bpf_printk(fmt, ##args)
#else
#define BPF_DEBUG(fmt, args...)
#endif
#define BPF_DEBUG_IP(s, ip) BPF_DEBUG("%s%u.%u.%u.%u", s, (ip >> 24) & 0xFF, (ip >> 16) & 0xFF, (ip >> 8) & 0xFF, ip & 0xFF);
#define BPF_DEBUG_MAC(s, mac) BPF_DEBUG("%s%02x:%02x:%02x:%02x:%02x:%02x", s, mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

// Helper macro to make the out-of-bounds check on a packet header and drop the package on failure
#define parse_header(header_type, header_ptr, data_ptr, data_end) \
    header_type header_ptr = data_ptr; \
	data_ptr += sizeof(header_type); \
    if (data_ptr > data_end) { \
        BPF_DEBUG(#header_type" > data_end"); \
        return BPF_DROP; \
    }


#endif
