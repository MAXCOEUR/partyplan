//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'dart:core';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

part 'purchase_body_purchased_quantity.g.dart';

/// PurchaseBodyPurchasedQuantity
@BuiltValue()
abstract class PurchaseBodyPurchasedQuantity implements Built<PurchaseBodyPurchasedQuantity, PurchaseBodyPurchasedQuantityBuilder> {
  /// Any Of [String], [num]
  AnyOf get anyOf;

  PurchaseBodyPurchasedQuantity._();

  factory PurchaseBodyPurchasedQuantity([void updates(PurchaseBodyPurchasedQuantityBuilder b)]) = _$PurchaseBodyPurchasedQuantity;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PurchaseBodyPurchasedQuantityBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PurchaseBodyPurchasedQuantity> get serializer => _$PurchaseBodyPurchasedQuantitySerializer();
}

class _$PurchaseBodyPurchasedQuantitySerializer implements PrimitiveSerializer<PurchaseBodyPurchasedQuantity> {
  @override
  final Iterable<Type> types = const [PurchaseBodyPurchasedQuantity, _$PurchaseBodyPurchasedQuantity];

  @override
  final String wireName = r'PurchaseBodyPurchasedQuantity';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PurchaseBodyPurchasedQuantity object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
  }

  @override
  Object serialize(
    Serializers serializers,
    PurchaseBodyPurchasedQuantity object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final anyOf = object.anyOf;
    return serializers.serialize(anyOf, specifiedType: FullType(AnyOf, anyOf.types.map((type) => FullType(type)).toList()))!;
  }

  @override
  PurchaseBodyPurchasedQuantity deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PurchaseBodyPurchasedQuantityBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [FullType(num), FullType(String), ]);
    anyOfDataSrc = serialized;
    result.anyOf = serializers.deserialize(anyOfDataSrc, specifiedType: targetType) as AnyOf;
    return result.build();
  }
}


