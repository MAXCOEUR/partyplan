//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'my_profile.g.dart';

/// Profil renvoyé à son titulaire.
///
/// Properties:
/// * [id] 
/// * [email] 
/// * [emailVerified] 
/// * [displayName] 
/// * [avatarUrl] 
/// * [locale] 
/// * [timezone] 
/// * [platformRole] 
/// * [hasPassword] 
/// * [totpEnabled] 
/// * [mustChangePassword] 
/// * [premiumUntil] 
/// * [createdAt] 
@BuiltValue()
abstract class MyProfile implements Built<MyProfile, MyProfileBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'email')
  String? get email;

  @BuiltValueField(wireName: r'emailVerified')
  bool get emailVerified;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'avatarUrl')
  String? get avatarUrl;

  @BuiltValueField(wireName: r'locale')
  String get locale;

  @BuiltValueField(wireName: r'timezone')
  String get timezone;

  @BuiltValueField(wireName: r'platformRole')
  String get platformRole;

  @BuiltValueField(wireName: r'hasPassword')
  bool get hasPassword;

  @BuiltValueField(wireName: r'totpEnabled')
  bool get totpEnabled;

  @BuiltValueField(wireName: r'mustChangePassword')
  bool get mustChangePassword;

  @BuiltValueField(wireName: r'premiumUntil')
  DateTime? get premiumUntil;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  MyProfile._();

  factory MyProfile([void updates(MyProfileBuilder b)]) = _$MyProfile;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MyProfileBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MyProfile> get serializer => _$MyProfileSerializer();
}

class _$MyProfileSerializer implements PrimitiveSerializer<MyProfile> {
  @override
  final Iterable<Type> types = const [MyProfile, _$MyProfile];

  @override
  final String wireName = r'MyProfile';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MyProfile object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'email';
    yield object.email == null ? null : serializers.serialize(
      object.email,
      specifiedType: const FullType.nullable(String),
    );
    yield r'emailVerified';
    yield serializers.serialize(
      object.emailVerified,
      specifiedType: const FullType(bool),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'avatarUrl';
    yield object.avatarUrl == null ? null : serializers.serialize(
      object.avatarUrl,
      specifiedType: const FullType.nullable(String),
    );
    yield r'locale';
    yield serializers.serialize(
      object.locale,
      specifiedType: const FullType(String),
    );
    yield r'timezone';
    yield serializers.serialize(
      object.timezone,
      specifiedType: const FullType(String),
    );
    yield r'platformRole';
    yield serializers.serialize(
      object.platformRole,
      specifiedType: const FullType(String),
    );
    yield r'hasPassword';
    yield serializers.serialize(
      object.hasPassword,
      specifiedType: const FullType(bool),
    );
    yield r'totpEnabled';
    yield serializers.serialize(
      object.totpEnabled,
      specifiedType: const FullType(bool),
    );
    yield r'mustChangePassword';
    yield serializers.serialize(
      object.mustChangePassword,
      specifiedType: const FullType(bool),
    );
    yield r'premiumUntil';
    yield object.premiumUntil == null ? null : serializers.serialize(
      object.premiumUntil,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MyProfile object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MyProfileBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.email = valueDes;
          break;
        case r'emailVerified':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.emailVerified = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'avatarUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.avatarUrl = valueDes;
          break;
        case r'locale':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.locale = valueDes;
          break;
        case r'timezone':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.timezone = valueDes;
          break;
        case r'platformRole':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.platformRole = valueDes;
          break;
        case r'hasPassword':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.hasPassword = valueDes;
          break;
        case r'totpEnabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.totpEnabled = valueDes;
          break;
        case r'mustChangePassword':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.mustChangePassword = valueDes;
          break;
        case r'premiumUntil':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.premiumUntil = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MyProfile deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MyProfileBuilder();
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


