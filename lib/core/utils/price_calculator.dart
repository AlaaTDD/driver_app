// lib/core/utils/price_calculator.dart

class PriceCalculator {
  static double calculatePrice({
    required String vehicleType,
    required double distanceKm,
    required double basePrice,
    required double pricePerKm,
  }) {
    // FIX M15: Vehicle type multipliers — motorcycle was missing (defaulted to 1.0 = same as sedan)
    double multiplier = 1.0;
    switch (vehicleType.toLowerCase()) {
      case 'sedan':
        multiplier = 1.0;
        break;
      case 'motorcycle':
        multiplier = 0.7;
        break;
      case 'suv':
        multiplier = 1.2;
        break;
      case 'van':
        multiplier = 1.4;
        break;
      default:
        multiplier = 1.0;
    }
    
    double totalPrice = basePrice + (distanceKm * pricePerKm * multiplier);
    return double.parse(totalPrice.toStringAsFixed(2));
  }

  static double applyCoupon({
    required double originalPrice,
    required String discountType,
    required double discountValue,
    required bool isActive,
  }) {
    if (!isActive) return originalPrice;
    
    double discountedPrice = originalPrice;
    
    if (discountType == 'percentage') {
      discountedPrice = originalPrice - (originalPrice * discountValue / 100);
    } else if (discountType == 'fixed') {
      discountedPrice = originalPrice - discountValue;
    }
    
    if (discountedPrice < 0) discountedPrice = 0;
    
    return double.parse(discountedPrice.toStringAsFixed(2));
  }
}
