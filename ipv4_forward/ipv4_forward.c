#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>

#include <arpa/inet.h>
#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>

#define DEBUG 0
#include "common_xdp_tc.h"


enum {
	ACTION_PASS = 1,
	ACTION_DROP,
	ACTION_REDIRECT
};

struct forward_key {
	__u32  ifindex;
	__be32 src_ip, dst_ip;
};

struct forward_value {
	__u32 ifindex;
	__u8 src_mac[ETH_ALEN];
	__u8 dst_mac[ETH_ALEN];
	__u8 action;
};

struct {
	__uint(type, BPF_MAP_TYPE_LRU_HASH);
	__type(key, struct forward_key);
	__type(value, struct forward_value);
	__uint(max_entries, 64);
} fwd_map SEC(".maps");


__always_inline void make_routing_decision(struct BPF_CTX *ctx, struct iphdr* iph, struct forward_value* fwd_val) {
	// Fill the lookup key
	struct bpf_fib_lookup fib_params = {};
	fib_params.family = AF_INET;
	fib_params.l4_protocol = iph->protocol;
	fib_params.tos = iph->tos;
	fib_params.ipv4_src = iph->saddr;
	fib_params.ipv4_dst = iph->daddr;
	fib_params.ifindex = ctx->ingress_ifindex;

	// Do a loopkup in the kernel routing table
	long rc = bpf_fib_lookup(ctx, &fib_params, sizeof(fib_params), 0);
	BPF_DEBUG("bpf_fib_lookup: %d", rc);

	switch (rc) { 
		case BPF_FIB_LKUP_RET_SUCCESS:      // lookup successful
			BPF_DEBUG("ifindex: %d", fib_params.ifindex);
			BPF_DEBUG_MAC("Source MAC: ", fib_params.smac);
			BPF_DEBUG_MAC("Destination MAC: ", fib_params.dmac);

			// Save the MAC addresses inside the map
			memcpy(fwd_val->src_mac, fib_params.smac, ETH_ALEN);
			memcpy(fwd_val->dst_mac, fib_params.dmac, ETH_ALEN);

			fwd_val->ifindex = fib_params.ifindex;
			fwd_val->action  = ACTION_REDIRECT;
		break;

		case BPF_FIB_LKUP_RET_UNREACHABLE:  // dest is unreachable
		case BPF_FIB_LKUP_RET_PROHIBIT:     // dest not allowed
		case BPF_FIB_LKUP_RET_NOT_FWDED:    // packet is not forwarded 
		case BPF_FIB_LKUP_RET_FWD_DISABLED: // fwdding is not enabled on ingress 
		case BPF_FIB_LKUP_RET_UNSUPP_LWT:   // fwdd requires encapsulation 
		case BPF_FIB_LKUP_RET_NO_NEIGH:     // no neighbor entry for nh
			fwd_val->action  = ACTION_PASS;
		break;

		case BPF_FIB_LKUP_RET_BLACKHOLE:    // dest is blackholed; can be dropped
		default:
			fwd_val->action  = ACTION_DROP;
	}
}

__always_inline void cksum_add(__sum16 *cksum, __sum16 addend) {
	__u16 res = (__u16)*cksum + (__u16)addend;
	*cksum = (__sum16)(res + (res < (__u16)addend));
}

__always_inline long redirect_package(struct ethhdr* ethh, struct iphdr* iph, struct forward_value* fwd_val) {
	// Decrement the TTL
	iph->ttl--;

	// Adjust the checksum
	cksum_add(&iph->check, bpf_htons(0x0100));

	// Adjust the MAC addresses
	memcpy(ethh->h_source, fwd_val->src_mac, ETH_ALEN);
	memcpy(ethh->h_dest,   fwd_val->dst_mac, ETH_ALEN);

	// Redirect the package
	return bpf_redirect(fwd_val->ifindex, 0);
}


SEC("ipv4_forward")
int ipv4_forward_func(struct BPF_CTX *ctx) {
	void* data 	   = (void*)(long)ctx->data;
	void* data_end = (void*)(long)ctx->data_end;

	parse_header(struct ethhdr, *ethh, data, data_end);

	if (ethh->h_proto != bpf_htons(ETH_P_IP))
		return BPF_PASS;

	BPF_DEBUG("---------- New IPv4 package received ----------");

	parse_header(struct iphdr, *iph, data, data_end);

	BPF_DEBUG_IP("Source IP: ", bpf_ntohl(iph->saddr));
	BPF_DEBUG_IP("Destination IP: ", bpf_ntohl(iph->daddr));

	struct forward_key fwd_key = {};
	fwd_key.ifindex = ctx->ingress_ifindex;
	fwd_key.src_ip  = iph->saddr;
	fwd_key.dst_ip  = iph->daddr;

	struct forward_value* fwd_val = bpf_map_lookup_elem(&fwd_map, &fwd_key);
	if (!fwd_val) {
		struct forward_value new_fwd = {};

		make_routing_decision(ctx, iph, &new_fwd);
		bpf_map_update_elem(&fwd_map, &fwd_key, &new_fwd, BPF_NOEXIST);
		
		fwd_val = bpf_map_lookup_elem(&fwd_map, &fwd_key);
		if (!fwd_val)
			return BPF_DROP;
	}

	switch (fwd_val->action) {
		case ACTION_REDIRECT:
			if (iph->ttl <= 1)
				return BPF_PASS;

			return redirect_package(ethh, iph, fwd_val);

		case ACTION_PASS:
			return BPF_PASS;

		case ACTION_DROP:
		default:
			return BPF_DROP;
	}
}

char _license[] SEC("license") = "GPL";
