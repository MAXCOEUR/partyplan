//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'dart:core';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

part 'attendance_body_extra_guests.g.dart';

/// AttendanceBodyExtraGuests
@BuiltValue()
abstract class AttendanceBodyExtraGuests implements Built<AttendanceBodyExtraGuests, AttendanceBodyExtraGuestsBuilder> {
  /// Any Of [String], [int]
  AnyOf get anyOf;

  AttendanceBodyExtraGuests._();

  factory AttendanceBodyExtraGuests([void updates(AttendanceBodyExtraGuestsBuilder b)]) = _$AttendanceBodyExtraGuests;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttendanceBodyExtraGuestsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttendanceBodyExtraGuests> get serializer => _$AttendanceBodyExtraGuestsSerializer();
}

class _$AttendanceBodyExtraGuestsSerializer implements PrimitiveSerializer<AttendanceBodyExtraGuests> {
  @override
  final Iterable<Type> types = const [AttendanceBodyExtraGuests, _$AttendanceBodyExtraGuests];

  @override
  final String wireName = r'AttendanceBodyExtraGuests';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttendanceBodyExtraGuests object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
  }

  @override
  Object serialize(
    Serializers serializers,
    AttendanceBodyExtraGuests object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final anyOf = object.anyOf;
    return serializers.serialize(anyOf, specifiedType: FullType(AnyOf, anyOf.types.map((type) => FullType(type)).toList()))!;
  }

  @override
  AttendanceBodyExtraGuests deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttendanceBodyExtraGuestsBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [FullType(int), FullType(String), ]);
    anyOfDataSrc = serialized;
    result.anyOf = serializers.deserialize(anyOfDataSrc, specifiedType: targetType) as AnyOf;
    return result.build();
  }
}


