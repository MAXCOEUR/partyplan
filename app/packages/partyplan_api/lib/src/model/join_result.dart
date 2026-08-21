//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'join_result.g.dart';

/// Résultat d'une participation : la session d'invité, ou la confirmation d'adhésion.
///
/// Properties:
/// * [eventId] 
/// * [memberId] 
/// * [guestToken] 
/// * [guestTokenExpiresAt] 
@BuiltValue()
abstract class JoinResult implements Built<JoinResult, JoinResultBuilder> {
  @BuiltValueField(wireName: r'eventId')
  String get eventId;

  @BuiltValueField(wireName: r'memberId')
  String get memberId;

  @BuiltValueField(wireName: r'guestToken')
  String? get guestToken;

  @BuiltValueField(wireName: r'guestTokenExpiresAt')
  DateTime? get guestTokenExpiresAt;

  JoinResult._();

  factory JoinResult([void updates(JoinResultBuilder b)]) = _$JoinResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(JoinResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<JoinResult> get serializer => _$JoinResultSerializer();
}

class _$JoinResultSerializer implements PrimitiveSerializer<JoinResult> {
  @override
  final Iterable<Type> types = const [JoinResult, _$JoinResult];

  @override
  final String wireName = r'JoinResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    JoinResult object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'eventId';
    yield serializers.serialize(
      object.eventId,
      specifiedType: const FullType(String),
    );
    yield r'memberId';
    yield serializers.serialize(
      object.memberId,
      specifiedType: const FullType(String),
    );
    yield r'guestToken';
    yield object.guestToken == null ? null : serializers.serialize(
      object.guestToken,
      specifiedType: const FullType.nullable(String),
    );
    yield r'guestTokenExpiresAt';
    yield object.guestTokenExpiresAt == null ? null : serializers.serialize(
      object.guestTokenExpiresAt,
      specifiedType: const FullType.nullable(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    JoinResult object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required JoinResultBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'eventId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.eventId = valueDes;
          break;
        case r'memberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.memberId = valueDes;
          break;
        case r'guestToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.guestToken = valueDes;
          break;
        case r'guestTokenExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.guestTokenExpiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  JoinResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = JoinResultBuilder();
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


