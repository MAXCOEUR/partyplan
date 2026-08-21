//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'totp_enrollment.g.dart';

/// Éléments d'enrôlement remis au client (EF-AUTH-12).
///
/// Properties:
/// * [secret] 
/// * [otpAuthUri] 
@BuiltValue()
abstract class TotpEnrollment implements Built<TotpEnrollment, TotpEnrollmentBuilder> {
  @BuiltValueField(wireName: r'secret')
  String get secret;

  @BuiltValueField(wireName: r'otpAuthUri')
  String get otpAuthUri;

  TotpEnrollment._();

  factory TotpEnrollment([void updates(TotpEnrollmentBuilder b)]) = _$TotpEnrollment;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TotpEnrollmentBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TotpEnrollment> get serializer => _$TotpEnrollmentSerializer();
}

class _$TotpEnrollmentSerializer implements PrimitiveSerializer<TotpEnrollment> {
  @override
  final Iterable<Type> types = const [TotpEnrollment, _$TotpEnrollment];

  @override
  final String wireName = r'TotpEnrollment';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TotpEnrollment object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'secret';
    yield serializers.serialize(
      object.secret,
      specifiedType: const FullType(String),
    );
    yield r'otpAuthUri';
    yield serializers.serialize(
      object.otpAuthUri,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TotpEnrollment object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TotpEnrollmentBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'secret':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.secret = valueDes;
          break;
        case r'otpAuthUri':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.otpAuthUri = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TotpEnrollment deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TotpEnrollmentBuilder();
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


