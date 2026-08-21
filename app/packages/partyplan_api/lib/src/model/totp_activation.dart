//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'totp_activation.g.dart';

/// Résultat d'une activation : les codes de secours, affichés une seule fois.
///
/// Properties:
/// * [recoveryCodes] 
@BuiltValue()
abstract class TotpActivation implements Built<TotpActivation, TotpActivationBuilder> {
  @BuiltValueField(wireName: r'recoveryCodes')
  BuiltList<String> get recoveryCodes;

  TotpActivation._();

  factory TotpActivation([void updates(TotpActivationBuilder b)]) = _$TotpActivation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TotpActivationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TotpActivation> get serializer => _$TotpActivationSerializer();
}

class _$TotpActivationSerializer implements PrimitiveSerializer<TotpActivation> {
  @override
  final Iterable<Type> types = const [TotpActivation, _$TotpActivation];

  @override
  final String wireName = r'TotpActivation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TotpActivation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'recoveryCodes';
    yield serializers.serialize(
      object.recoveryCodes,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TotpActivation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TotpActivationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'recoveryCodes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.recoveryCodes.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TotpActivation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TotpActivationBuilder();
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


