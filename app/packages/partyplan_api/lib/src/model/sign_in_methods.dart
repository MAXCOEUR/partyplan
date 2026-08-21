//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/provider_state.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sign_in_methods.g.dart';

///             Moyens de connexion d'un compte (EF-AUTH-08).             Le sujet transmis par le fournisseur n'est jamais exposé : l'écran n'en a pas besoin, et une réponse d'API ne porte pas d'identifiant tiers.
///
/// Properties:
/// * [hasPassword] 
/// * [providers] 
@BuiltValue()
abstract class SignInMethods implements Built<SignInMethods, SignInMethodsBuilder> {
  @BuiltValueField(wireName: r'hasPassword')
  bool get hasPassword;

  @BuiltValueField(wireName: r'providers')
  BuiltList<ProviderState> get providers;

  SignInMethods._();

  factory SignInMethods([void updates(SignInMethodsBuilder b)]) = _$SignInMethods;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SignInMethodsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SignInMethods> get serializer => _$SignInMethodsSerializer();
}

class _$SignInMethodsSerializer implements PrimitiveSerializer<SignInMethods> {
  @override
  final Iterable<Type> types = const [SignInMethods, _$SignInMethods];

  @override
  final String wireName = r'SignInMethods';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SignInMethods object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'hasPassword';
    yield serializers.serialize(
      object.hasPassword,
      specifiedType: const FullType(bool),
    );
    yield r'providers';
    yield serializers.serialize(
      object.providers,
      specifiedType: const FullType(BuiltList, [FullType(ProviderState)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SignInMethods object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SignInMethodsBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'hasPassword':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.hasPassword = valueDes;
          break;
        case r'providers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ProviderState)]),
          ) as BuiltList<ProviderState>;
          result.providers.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SignInMethods deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SignInMethodsBuilder();
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


