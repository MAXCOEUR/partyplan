//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'share_body.g.dart';

/// ShareBody
///
/// Properties:
/// * [memberId] 
/// * [share] 
@BuiltValue()
abstract class ShareBody implements Built<ShareBody, ShareBodyBuilder> {
  @BuiltValueField(wireName: r'memberId')
  String get memberId;

  @BuiltValueField(wireName: r'share')
  AdminListUsersPageParameter get share;

  ShareBody._();

  factory ShareBody([void updates(ShareBodyBuilder b)]) = _$ShareBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ShareBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ShareBody> get serializer => _$ShareBodySerializer();
}

class _$ShareBodySerializer implements PrimitiveSerializer<ShareBody> {
  @override
  final Iterable<Type> types = const [ShareBody, _$ShareBody];

  @override
  final String wireName = r'ShareBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ShareBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'memberId';
    yield serializers.serialize(
      object.memberId,
      specifiedType: const FullType(String),
    );
    yield r'share';
    yield serializers.serialize(
      object.share,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ShareBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ShareBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'memberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.memberId = valueDes;
          break;
        case r'share':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.share.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ShareBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ShareBodyBuilder();
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


