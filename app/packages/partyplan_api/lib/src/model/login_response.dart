//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'login_response.g.dart';

/// Réponse de connexion. Soit les jetons de session, soit un défi de second facteur — jamais les deux.
///
/// Properties:
/// * [requiresSecondFactor] 
/// * [accessToken] 
/// * [accessTokenExpiresAt] 
/// * [refreshToken] 
/// * [refreshTokenExpiresAt] 
/// * [challengeToken] 
/// * [challengeExpiresAt] 
@BuiltValue()
abstract class LoginResponse implements Built<LoginResponse, LoginResponseBuilder> {
  @BuiltValueField(wireName: r'requiresSecondFactor')
  bool get requiresSecondFactor;

  @BuiltValueField(wireName: r'accessToken')
  String? get accessToken;

  @BuiltValueField(wireName: r'accessTokenExpiresAt')
  DateTime? get accessTokenExpiresAt;

  @BuiltValueField(wireName: r'refreshToken')
  String? get refreshToken;

  @BuiltValueField(wireName: r'refreshTokenExpiresAt')
  DateTime? get refreshTokenExpiresAt;

  @BuiltValueField(wireName: r'challengeToken')
  String? get challengeToken;

  @BuiltValueField(wireName: r'challengeExpiresAt')
  DateTime? get challengeExpiresAt;

  LoginResponse._();

  factory LoginResponse([void updates(LoginResponseBuilder b)]) = _$LoginResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LoginResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LoginResponse> get serializer => _$LoginResponseSerializer();
}

class _$LoginResponseSerializer implements PrimitiveSerializer<LoginResponse> {
  @override
  final Iterable<Type> types = const [LoginResponse, _$LoginResponse];

  @override
  final String wireName = r'LoginResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LoginResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'requiresSecondFactor';
    yield serializers.serialize(
      object.requiresSecondFactor,
      specifiedType: const FullType(bool),
    );
    yield r'accessToken';
    yield object.accessToken == null ? null : serializers.serialize(
      object.accessToken,
      specifiedType: const FullType.nullable(String),
    );
    yield r'accessTokenExpiresAt';
    yield object.accessTokenExpiresAt == null ? null : serializers.serialize(
      object.accessTokenExpiresAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'refreshToken';
    yield object.refreshToken == null ? null : serializers.serialize(
      object.refreshToken,
      specifiedType: const FullType.nullable(String),
    );
    yield r'refreshTokenExpiresAt';
    yield object.refreshTokenExpiresAt == null ? null : serializers.serialize(
      object.refreshTokenExpiresAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'challengeToken';
    yield object.challengeToken == null ? null : serializers.serialize(
      object.challengeToken,
      specifiedType: const FullType.nullable(String),
    );
    yield r'challengeExpiresAt';
    yield object.challengeExpiresAt == null ? null : serializers.serialize(
      object.challengeExpiresAt,
      specifiedType: const FullType.nullable(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LoginResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LoginResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'requiresSecondFactor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.requiresSecondFactor = valueDes;
          break;
        case r'accessToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.accessToken = valueDes;
          break;
        case r'accessTokenExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.accessTokenExpiresAt = valueDes;
          break;
        case r'refreshToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.refreshToken = valueDes;
          break;
        case r'refreshTokenExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.refreshTokenExpiresAt = valueDes;
          break;
        case r'challengeToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.challengeToken = valueDes;
          break;
        case r'challengeExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.challengeExpiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LoginResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LoginResponseBuilder();
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


