//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'claim_guest_request.g.dart';

///             Rattachement d'une participation d'invité au compte connecté (EF-AUTH-11).             Endpoint distinct plutôt que champ ajouté à l'inscription et à la connexion : l'API compte quatre points d'ouverture de session — inscription, connexion, second facteur, connexion tierce. Un champ n'en couvrirait que deux, et tout compte protégé par un second facteur perdrait silencieusement sa participation.
///
/// Properties:
/// * [guestToken] 
@BuiltValue()
abstract class ClaimGuestRequest implements Built<ClaimGuestRequest, ClaimGuestRequestBuilder> {
  @BuiltValueField(wireName: r'guestToken')
  String get guestToken;

  ClaimGuestRequest._();

  factory ClaimGuestRequest([void updates(ClaimGuestRequestBuilder b)]) = _$ClaimGuestRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ClaimGuestRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ClaimGuestRequest> get serializer => _$ClaimGuestRequestSerializer();
}

class _$ClaimGuestRequestSerializer implements PrimitiveSerializer<ClaimGuestRequest> {
  @override
  final Iterable<Type> types = const [ClaimGuestRequest, _$ClaimGuestRequest];

  @override
  final String wireName = r'ClaimGuestRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ClaimGuestRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'guestToken';
    yield serializers.serialize(
      object.guestToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ClaimGuestRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ClaimGuestRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'guestToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.guestToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ClaimGuestRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ClaimGuestRequestBuilder();
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


