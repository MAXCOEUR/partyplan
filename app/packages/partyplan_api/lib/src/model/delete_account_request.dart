//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'delete_account_request.g.dart';

/// Suppression de compte. L'adresse est exigée en confirmation : l'opération est irréversible et touche des données financières partagées (RG-USR-05).
///
/// Properties:
/// * [emailConfirmation] 
@BuiltValue()
abstract class DeleteAccountRequest implements Built<DeleteAccountRequest, DeleteAccountRequestBuilder> {
  @BuiltValueField(wireName: r'emailConfirmation')
  String get emailConfirmation;

  DeleteAccountRequest._();

  factory DeleteAccountRequest([void updates(DeleteAccountRequestBuilder b)]) = _$DeleteAccountRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeleteAccountRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeleteAccountRequest> get serializer => _$DeleteAccountRequestSerializer();
}

class _$DeleteAccountRequestSerializer implements PrimitiveSerializer<DeleteAccountRequest> {
  @override
  final Iterable<Type> types = const [DeleteAccountRequest, _$DeleteAccountRequest];

  @override
  final String wireName = r'DeleteAccountRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeleteAccountRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'emailConfirmation';
    yield serializers.serialize(
      object.emailConfirmation,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeleteAccountRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeleteAccountRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'emailConfirmation':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.emailConfirmation = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeleteAccountRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeleteAccountRequestBuilder();
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


