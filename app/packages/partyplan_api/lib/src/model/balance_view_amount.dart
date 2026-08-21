//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'dart:core';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

part 'balance_view_amount.g.dart';

/// BalanceViewAmount
@BuiltValue()
abstract class BalanceViewAmount implements Built<BalanceViewAmount, BalanceViewAmountBuilder> {
  /// Any Of [String], [num]
  AnyOf get anyOf;

  BalanceViewAmount._();

  factory BalanceViewAmount([void updates(BalanceViewAmountBuilder b)]) = _$BalanceViewAmount;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BalanceViewAmountBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BalanceViewAmount> get serializer => _$BalanceViewAmountSerializer();
}

class _$BalanceViewAmountSerializer implements PrimitiveSerializer<BalanceViewAmount> {
  @override
  final Iterable<Type> types = const [BalanceViewAmount, _$BalanceViewAmount];

  @override
  final String wireName = r'BalanceViewAmount';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BalanceViewAmount object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
  }

  @override
  Object serialize(
    Serializers serializers,
    BalanceViewAmount object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final anyOf = object.anyOf;
    return serializers.serialize(anyOf, specifiedType: FullType(AnyOf, anyOf.types.map((type) => FullType(type)).toList()))!;
  }

  @override
  BalanceViewAmount deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BalanceViewAmountBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [FullType(num), FullType(String), ]);
    anyOfDataSrc = serialized;
    result.anyOf = serializers.deserialize(anyOfDataSrc, specifiedType: targetType) as AnyOf;
    return result.build();
  }
}


