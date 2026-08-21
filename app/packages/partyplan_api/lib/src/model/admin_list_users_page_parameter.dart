//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'dart:core';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

part 'admin_list_users_page_parameter.g.dart';

/// AdminListUsersPageParameter
@BuiltValue()
abstract class AdminListUsersPageParameter implements Built<AdminListUsersPageParameter, AdminListUsersPageParameterBuilder> {
  /// Any Of [String], [int]
  AnyOf get anyOf;

  AdminListUsersPageParameter._();

  factory AdminListUsersPageParameter([void updates(AdminListUsersPageParameterBuilder b)]) = _$AdminListUsersPageParameter;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AdminListUsersPageParameterBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AdminListUsersPageParameter> get serializer => _$AdminListUsersPageParameterSerializer();
}

class _$AdminListUsersPageParameterSerializer implements PrimitiveSerializer<AdminListUsersPageParameter> {
  @override
  final Iterable<Type> types = const [AdminListUsersPageParameter, _$AdminListUsersPageParameter];

  @override
  final String wireName = r'AdminListUsersPageParameter';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AdminListUsersPageParameter object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
  }

  @override
  Object serialize(
    Serializers serializers,
    AdminListUsersPageParameter object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final anyOf = object.anyOf;
    return serializers.serialize(anyOf, specifiedType: FullType(AnyOf, anyOf.types.map((type) => FullType(type)).toList()))!;
  }

  @override
  AdminListUsersPageParameter deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AdminListUsersPageParameterBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [FullType(int), FullType(String), ]);
    anyOfDataSrc = serialized;
    result.anyOf = serializers.deserialize(anyOfDataSrc, specifiedType: targetType) as AnyOf;
    return result.build();
  }
}


