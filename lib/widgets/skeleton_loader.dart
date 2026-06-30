import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Kotak/bar abu-abu dengan sudut membulat — building block dasar skeleton.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Lingkaran abu-abu — untuk skeleton avatar/ikon bundar.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Wrapper shimmer global — bungkus seluruh skeleton dengan efek kilau bergerak.
/// Pakai ini satu kali di luar, lalu taruh SkeletonBox/SkeletonCircle di dalamnya.
class ShimmerWrapper extends StatelessWidget {
  final Widget child;

  const ShimmerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// ── Skeleton siap pakai: 1 kartu riwayat ──────────────────────────────────
class RiwayatCardSkeleton extends StatelessWidget {
  const RiwayatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 140, height: 14),
                const SizedBox(height: 8),
                const SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 40, height: 20, radius: 8),
        ],
      ),
    );
  }
}

/// ── Skeleton siap pakai: card skor besar (mis. "Skor Simulasi Terakhir") ──
class ScoreCardSkeleton extends StatelessWidget {
  const ScoreCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 130, height: 12),
          const SizedBox(height: 12),
          const SkeletonBox(width: 90, height: 36, radius: 8),
        ],
      ),
    );
  }
}

/// ── Skeleton lengkap untuk halaman Riwayat (dipakai saat _isLoading) ──────
class RiwayatScreenSkeleton extends StatelessWidget {
  const RiwayatScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const ScoreCardSkeleton(),
          const SizedBox(height: 20),

          // Filter chips skeleton
          Row(
            children: [
              const SkeletonBox(width: 70, height: 32, radius: 20),
              const SizedBox(width: 8),
              const SkeletonBox(width: 70, height: 32, radius: 20),
              const SizedBox(width: 8),
              const SkeletonBox(width: 70, height: 32, radius: 20),
            ],
          ),
          const SizedBox(height: 16),

          // Beberapa kartu riwayat skeleton
          const RiwayatCardSkeleton(),
          const RiwayatCardSkeleton(),
          const RiwayatCardSkeleton(),
          const RiwayatCardSkeleton(),
        ],
      ),
    );
  }
}