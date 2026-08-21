//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'join_preview.g.dart';

///             Aperçu d'un événement avant participation (RG-INV-04).             Volontairement pauvre : nom, date, lieu, nombre de participants. Ni liste nominative, ni dépenses, ni discussion. Quiconque détient le lien voit ceci, et rien de plus, jusqu'à ce qu'il rejoigne.
///
/// Properties:
/// * [name] 
/// * [startsAt] 
/// * [endsAt] 
/// * [address] 
/// * [description] 
/// * [participantCount] 
/// * [joinEnabled] 
/// * [alreadyMember] 
@BuiltValue()
abstract class JoinPreview implements Built<JoinPreview, JoinPreviewBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'startsAt')
  DateTime get startsAt;

  @BuiltValueField(wireName: r'endsAt')
  DateTime? get endsAt;

  @BuiltValueField(wireName: r'address')
  String? get address;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'participantCount')
  AdminListUsersPageParameter get participantCount;

  @BuiltValueField(wireName: r'joinEnabled')
  bool get joinEnabled;

  @BuiltValueField(wireName: r'alreadyMember')
  bool get alreadyMember;

  JoinPreview._();

  factory JoinPreview([void updates(JoinPreviewBuilder b)]) = _$JoinPreview;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(JoinPreviewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<JoinPreview> get serializer => _$JoinPreviewSerializer();
}

class _$JoinPreviewSerializer implements PrimitiveSerializer<JoinPreview> {
  @override
  final Iterable<Type> types = const [JoinPreview, _$JoinPreview];

  @override
  final String wireName = r'JoinPreview';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    JoinPreview object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'startsAt';
    yield serializers.serialize(
      object.startsAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'endsAt';
    yield object.endsAt == null ? null : serializers.serialize(
      object.endsAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'address';
    yield object.address == null ? null : serializers.serialize(
      object.address,
      specifiedType: const FullType.nullable(String),
    );
    yield r'description';
    yield object.description == null ? null : serializers.serialize(
      object.description,
      specifiedType: const FullType.nullable(String),
    );
    yield r'participantCount';
    yield serializers.serialize(
      object.participantCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'joinEnabled';
    yield serializers.serialize(
      object.joinEnabled,
      specifiedType: const FullType(bool),
    );
    yield r'alreadyMember';
    yield serializers.serialize(
      object.alreadyMember,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    JoinPreview object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required JoinPreviewBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'startsAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.startsAt = valueDes;
          break;
        case r'endsAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.endsAt = valueDes;
          break;
        case r'address':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.address = valueDes;
          break;
        case r'description':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.description = valueDes;
          break;
        case r'participantCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.participantCount.replace(valueDes);
          break;
        case r'joinEnabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.joinEnabled = valueDes;
          break;
        case r'alreadyMember':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.alreadyMember = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  JoinPreview deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = JoinPreviewBuilder();
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


