// This is a generated file - do not edit.
//
// Generated from google/api/http.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Http extends $pb.GeneratedMessage {
  factory Http({
    $core.Iterable<HttpRule>? rules,
  }) {
    final result = create();
    if (rules != null) result.rules.addAll(rules);
    return result;
  }

  Http._();

  factory Http.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Http.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Http',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'google.api'),
      createEmptyInstance: create)
    ..pPM<HttpRule>(1, _omitFieldNames ? '' : 'rules',
        subBuilder: HttpRule.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Http clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Http copyWith(void Function(Http) updates) =>
      super.copyWith((message) => updates(message as Http)) as Http;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Http create() => Http._();
  @$core.override
  Http createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Http getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Http>(create);
  static Http? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<HttpRule> get rules => $_getList(0);
}

enum HttpRule_Pattern { get, put, post, delete, patch, custom, notSet }

class HttpRule extends $pb.GeneratedMessage {
  factory HttpRule({
    $core.String? selector,
    $core.String? get,
    $core.String? put,
    $core.String? post,
    $core.String? delete,
    $core.String? patch,
    $core.String? body,
    $core.String? custom,
    $core.String? responseBody,
    $core.Iterable<HttpRule>? additionalBindings,
  }) {
    final result = create();
    if (selector != null) result.selector = selector;
    if (get != null) result.get = get;
    if (put != null) result.put = put;
    if (post != null) result.post = post;
    if (delete != null) result.delete = delete;
    if (patch != null) result.patch = patch;
    if (body != null) result.body = body;
    if (custom != null) result.custom = custom;
    if (responseBody != null) result.responseBody = responseBody;
    if (additionalBindings != null)
      result.additionalBindings.addAll(additionalBindings);
    return result;
  }

  HttpRule._();

  factory HttpRule.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HttpRule.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, HttpRule_Pattern> _HttpRule_PatternByTag = {
    2: HttpRule_Pattern.get,
    3: HttpRule_Pattern.put,
    4: HttpRule_Pattern.post,
    5: HttpRule_Pattern.delete,
    6: HttpRule_Pattern.patch,
    8: HttpRule_Pattern.custom,
    0: HttpRule_Pattern.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HttpRule',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'google.api'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 8])
    ..aOS(1, _omitFieldNames ? '' : 'selector')
    ..aOS(2, _omitFieldNames ? '' : 'get')
    ..aOS(3, _omitFieldNames ? '' : 'put')
    ..aOS(4, _omitFieldNames ? '' : 'post')
    ..aOS(5, _omitFieldNames ? '' : 'delete')
    ..aOS(6, _omitFieldNames ? '' : 'patch')
    ..aOS(7, _omitFieldNames ? '' : 'body')
    ..aOS(8, _omitFieldNames ? '' : 'custom')
    ..aOS(10, _omitFieldNames ? '' : 'responseBody')
    ..pPM<HttpRule>(11, _omitFieldNames ? '' : 'additionalBindings',
        subBuilder: HttpRule.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HttpRule clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HttpRule copyWith(void Function(HttpRule) updates) =>
      super.copyWith((message) => updates(message as HttpRule)) as HttpRule;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HttpRule create() => HttpRule._();
  @$core.override
  HttpRule createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HttpRule getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HttpRule>(create);
  static HttpRule? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(8)
  HttpRule_Pattern whichPattern() => _HttpRule_PatternByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(8)
  void clearPattern() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get selector => $_getSZ(0);
  @$pb.TagNumber(1)
  set selector($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSelector() => $_has(0);
  @$pb.TagNumber(1)
  void clearSelector() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get get => $_getSZ(1);
  @$pb.TagNumber(2)
  set get($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGet() => $_has(1);
  @$pb.TagNumber(2)
  void clearGet() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get put => $_getSZ(2);
  @$pb.TagNumber(3)
  set put($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPut() => $_has(2);
  @$pb.TagNumber(3)
  void clearPut() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get post => $_getSZ(3);
  @$pb.TagNumber(4)
  set post($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPost() => $_has(3);
  @$pb.TagNumber(4)
  void clearPost() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get delete => $_getSZ(4);
  @$pb.TagNumber(5)
  set delete($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDelete() => $_has(4);
  @$pb.TagNumber(5)
  void clearDelete() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get patch => $_getSZ(5);
  @$pb.TagNumber(6)
  set patch($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPatch() => $_has(5);
  @$pb.TagNumber(6)
  void clearPatch() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get body => $_getSZ(6);
  @$pb.TagNumber(7)
  set body($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBody() => $_has(6);
  @$pb.TagNumber(7)
  void clearBody() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get custom => $_getSZ(7);
  @$pb.TagNumber(8)
  set custom($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCustom() => $_has(7);
  @$pb.TagNumber(8)
  void clearCustom() => $_clearField(8);

  @$pb.TagNumber(10)
  $core.String get responseBody => $_getSZ(8);
  @$pb.TagNumber(10)
  set responseBody($core.String value) => $_setString(8, value);
  @$pb.TagNumber(10)
  $core.bool hasResponseBody() => $_has(8);
  @$pb.TagNumber(10)
  void clearResponseBody() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<HttpRule> get additionalBindings => $_getList(9);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
