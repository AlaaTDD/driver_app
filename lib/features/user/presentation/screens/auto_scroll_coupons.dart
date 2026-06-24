import 'dart:async';
import 'package:flutter/material.dart';

class AutoScrollCoupons extends StatefulWidget {
  final List<Map<String, dynamic>> coupons;
  final Widget Function(Map<String, dynamic> coupon) itemBuilder;

  const AutoScrollCoupons({
    super.key,
    required this.coupons,
    required this.itemBuilder,
  });

  @override
  State<AutoScrollCoupons> createState() => _AutoScrollCouponsState();
}

class _AutoScrollCouponsState extends State<AutoScrollCoupons> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.coupons.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_scrollController.hasClients) {
          final double itemWidth = MediaQuery.of(context).size.width - 60 + 8;
          _currentIndex++;
          if (_currentIndex >= widget.coupons.length) {
            _currentIndex = 0;
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          } else {
            _scrollController.animateTo(
              _currentIndex * itemWidth,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: widget.coupons.map((coupon) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 60,
            child: widget.itemBuilder(coupon),
          ),
        )).toList(),
      ),
    );
  }
}
