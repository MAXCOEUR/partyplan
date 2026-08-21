//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'claim_guest_response.g.dart';

/// Nombre de participations rattachées. Zéro n'est pas une erreur.
///
/// Properties:
/// * [linked] 
@BuiltValue()
abstract class ClaimGuestResponse implements Built<ClaimGuestResponse, ClaimGuestResponseBuilder> {
  @BuiltValueField(wireName: r'linked')
  AdminListUsersPageParameter get linked;

  ClaimGuestResponse._();

  factory ClaimGuestResponse([void updates(ClaimGuestResponseBuilder b)]) = _$ClaimGuestResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ClaimGuestResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ClaimGuestResponse> get serializer => _$ClaimGuestResponseSerializer();
}

class _$ClaimGuestResponseSerializer implements PrimitiveSerializer<ClaimGuestResponse> {
  @override
  final Iterable<Type> types = const [ClaimGuestResponse, _$ClaimGuestResponse];

  @override
  final String wireName = r'ClaimGuestResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ClaimGuestResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'linked';
    yield serializers.serialize(
      object.linked,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ClaimGuestResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ClaimGuestResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'linked':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.linked.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ClaimGuestResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ClaimGuestResponseBuilder();
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


