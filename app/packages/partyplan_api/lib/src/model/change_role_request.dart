//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'change_role_request.g.dart';

/// ChangeRoleRequest
///
/// Properties:
/// * [role] 
@BuiltValue()
abstract class ChangeRoleRequest implements Built<ChangeRoleRequest, ChangeRoleRequestBuilder> {
  @BuiltValueField(wireName: r'role')
  String get role;

  ChangeRoleRequest._();

  factory ChangeRoleRequest([void updates(ChangeRoleRequestBuilder b)]) = _$ChangeRoleRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ChangeRoleRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ChangeRoleRequest> get serializer => _$ChangeRoleRequestSerializer();
}

class _$ChangeRoleRequestSerializer implements PrimitiveSerializer<ChangeRoleRequest> {
  @override
  final Iterable<Type> types = const [ChangeRoleRequest, _$ChangeRoleRequest];

  @override
  final String wireName = r'ChangeRoleRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ChangeRoleRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'role';
    yield serializers.serialize(
      object.role,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ChangeRoleRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ChangeRoleRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'role':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.role = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ChangeRoleRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ChangeRoleRequestBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


