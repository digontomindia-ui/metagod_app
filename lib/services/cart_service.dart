import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.price * quantity;
}

class CartService extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  UnmodifiableMapView<String, CartItem> get items => UnmodifiableMapView(_items);

  int get itemCount => _items.length;

  int get totalQuantity =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  int quantityOf(String productId) {
    return _items.containsKey(productId) ? _items[productId]!.quantity : 0;
  }

  void addToCart(Product product) {
    if (_items.containsKey(product.id)) {
      if (_items[product.id]!.quantity < product.stock) {
        _items[product.id]!.quantity++;
      }
    } else {
      if (product.stock > 0) {
        _items[product.id] = CartItem(product: product);
      }
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void incrementQuantity(String productId) {
    if (_items.containsKey(productId)) {
      final cartItem = _items[productId]!;
      if (cartItem.quantity < cartItem.product.stock) {
        cartItem.quantity++;
        notifyListeners();
      }
    }
  }

  void decrementQuantity(String productId) {
    if (_items.containsKey(productId)) {
      final cartItem = _items[productId]!;
      if (cartItem.quantity > 1) {
        cartItem.quantity--;
      } else {
        _items.remove(productId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  List<CartItem> get cartItems => _items.values.toList();
}
