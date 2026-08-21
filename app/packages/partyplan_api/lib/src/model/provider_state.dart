//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'provider_state.g.dart';

/// État d'un fournisseur tiers pour un compte donné (EF-AUTH-08). Configured et Linked sont indépendants : un fournisseur peut être rattaché à un compte alors que l'instance n'a plus de clé, et il doit alors rester détachable.
///
/// Properties:
/// * [provider] - Identifiant du fournisseur, en minuscules.
/// * [configured] - Vrai si cette instance dispose des clés nécessaires.
/// * [linked] - Vrai si ce compte est rattaché à ce fournisseur.
@BuiltValue()
abstract class ProviderState implements Built<ProviderState, ProviderStateBuilder> {
  /// Identifiant du fournisseur, en minuscules.
  @BuiltValueField(wireName: r'provider')
  String get provider;

  /// Vrai si cette instance dispose des clés nécessaires.
  @BuiltValueField(wireName: r'configured')
  bool get configured;

  /// Vrai si ce compte est rattaché à ce fournisseur.
  @BuiltValueField(wireName: r'linked')
  bool get linked;

  ProviderState._();

  factory ProviderState([void updates(ProviderStateBuilder b)]) = _$ProviderState;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ProviderStateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ProviderState> get serializer => _$ProviderStateSerializer();
}

class _$ProviderStateSerializer implements PrimitiveSerializer<ProviderState> {
  @override
  final Iterable<Type> types = const [ProviderState, _$ProviderState];

  @override
  final String wireName = r'ProviderState';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ProviderState object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'provider';
    yield serializers.serialize(
      object.provider,
      specifiedType: const FullType(String),
    );
    yield r'configured';
    yield serializers.serialize(
      object.configured,
      specifiedType: const FullType(bool),
    );
    yield r'linked';
    yield serializers.serialize(
      object.linked,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ProviderState object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ProviderStateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'provider':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.provider = valueDes;
          break;
        case r'configured':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.configured = valueDes;
          break;
        case r'linked':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.linked = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ProviderState deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ProviderStateBuilder();
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


