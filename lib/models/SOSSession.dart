/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:collection/collection.dart';


/** This is an auto generated class representing the SOSSession type in your schema. */
class SOSSession extends amplify_core.Model {
  static const classType = const _SOSSessionModelType();
  final String id;
  final String? _phoneNumber;
  final bool? _isActive;
  final double? _latitude;
  final double? _longitude;
  final String? _triggerType;
  final List<String>? _authorizedViewers;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  SOSSessionModelIdentifier get modelIdentifier {
      return SOSSessionModelIdentifier(
        id: id
      );
  }
  
  String get phoneNumber {
    try {
      return _phoneNumber!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  bool get isActive {
    try {
      return _isActive!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get latitude {
    try {
      return _latitude!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get longitude {
    try {
      return _longitude!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get triggerType {
    return _triggerType;
  }
  
  List<String>? get authorizedViewers {
    return _authorizedViewers;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const SOSSession._internal({required this.id, required phoneNumber, required isActive, required latitude, required longitude, triggerType, authorizedViewers, createdAt, updatedAt}): _phoneNumber = phoneNumber, _isActive = isActive, _latitude = latitude, _longitude = longitude, _triggerType = triggerType, _authorizedViewers = authorizedViewers, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory SOSSession({String? id, required String phoneNumber, required bool isActive, required double latitude, required double longitude, String? triggerType, List<String>? authorizedViewers}) {
    return SOSSession._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      phoneNumber: phoneNumber,
      isActive: isActive,
      latitude: latitude,
      longitude: longitude,
      triggerType: triggerType,
      authorizedViewers: authorizedViewers != null ? List<String>.unmodifiable(authorizedViewers) : authorizedViewers);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SOSSession &&
      id == other.id &&
      _phoneNumber == other._phoneNumber &&
      _isActive == other._isActive &&
      _latitude == other._latitude &&
      _longitude == other._longitude &&
      _triggerType == other._triggerType &&
      DeepCollectionEquality().equals(_authorizedViewers, other._authorizedViewers);
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("SOSSession {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("phoneNumber=" + "$_phoneNumber" + ", ");
    buffer.write("isActive=" + (_isActive != null ? _isActive!.toString() : "null") + ", ");
    buffer.write("latitude=" + (_latitude != null ? _latitude!.toString() : "null") + ", ");
    buffer.write("longitude=" + (_longitude != null ? _longitude!.toString() : "null") + ", ");
    buffer.write("triggerType=" + "$_triggerType" + ", ");
    buffer.write("authorizedViewers=" + (_authorizedViewers != null ? _authorizedViewers!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  SOSSession copyWith({String? phoneNumber, bool? isActive, double? latitude, double? longitude, String? triggerType, List<String>? authorizedViewers}) {
    return SOSSession._internal(
      id: id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      triggerType: triggerType ?? this.triggerType,
      authorizedViewers: authorizedViewers ?? this.authorizedViewers);
  }
  
  SOSSession copyWithModelFieldValues({
    ModelFieldValue<String>? phoneNumber,
    ModelFieldValue<bool>? isActive,
    ModelFieldValue<double>? latitude,
    ModelFieldValue<double>? longitude,
    ModelFieldValue<String?>? triggerType,
    ModelFieldValue<List<String>?>? authorizedViewers
  }) {
    return SOSSession._internal(
      id: id,
      phoneNumber: phoneNumber == null ? this.phoneNumber : phoneNumber.value,
      isActive: isActive == null ? this.isActive : isActive.value,
      latitude: latitude == null ? this.latitude : latitude.value,
      longitude: longitude == null ? this.longitude : longitude.value,
      triggerType: triggerType == null ? this.triggerType : triggerType.value,
      authorizedViewers: authorizedViewers == null ? this.authorizedViewers : authorizedViewers.value
    );
  }
  
  SOSSession.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _phoneNumber = json['phoneNumber'],
      _isActive = json['isActive'],
      _latitude = (json['latitude'] as num?)?.toDouble(),
      _longitude = (json['longitude'] as num?)?.toDouble(),
      _triggerType = json['triggerType'],
      _authorizedViewers = json['authorizedViewers']?.cast<String>(),
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'phoneNumber': _phoneNumber, 'isActive': _isActive, 'latitude': _latitude, 'longitude': _longitude, 'triggerType': _triggerType, 'authorizedViewers': _authorizedViewers, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'phoneNumber': _phoneNumber,
    'isActive': _isActive,
    'latitude': _latitude,
    'longitude': _longitude,
    'triggerType': _triggerType,
    'authorizedViewers': _authorizedViewers,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<SOSSessionModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<SOSSessionModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final PHONENUMBER = amplify_core.QueryField(fieldName: "phoneNumber");
  static final ISACTIVE = amplify_core.QueryField(fieldName: "isActive");
  static final LATITUDE = amplify_core.QueryField(fieldName: "latitude");
  static final LONGITUDE = amplify_core.QueryField(fieldName: "longitude");
  static final TRIGGERTYPE = amplify_core.QueryField(fieldName: "triggerType");
  static final AUTHORIZEDVIEWERS = amplify_core.QueryField(fieldName: "authorizedViewers");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "SOSSession";
    modelSchemaDefinition.pluralName = "SOSSessions";
    
    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.OWNER,
        ownerField: "owner",
        identityClaim: "cognito:username",
        provider: amplify_core.AuthRuleProvider.USERPOOLS,
        operations: const [
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE,
          amplify_core.ModelOperation.READ
        ]),
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.PUBLIC,
        operations: const [
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.READ,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE
        ])
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SOSSession.PHONENUMBER,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SOSSession.ISACTIVE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.bool)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SOSSession.LATITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SOSSession.LONGITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SOSSession.TRIGGERTYPE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SOSSession.AUTHORIZEDVIEWERS,
      isRequired: false,
      isArray: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.collection, ofModelName: amplify_core.ModelFieldTypeEnum.string.name)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _SOSSessionModelType extends amplify_core.ModelType<SOSSession> {
  const _SOSSessionModelType();
  
  @override
  SOSSession fromJson(Map<String, dynamic> jsonData) {
    return SOSSession.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'SOSSession';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [SOSSession] in your schema.
 */
class SOSSessionModelIdentifier implements amplify_core.ModelIdentifier<SOSSession> {
  final String id;

  /** Create an instance of SOSSessionModelIdentifier using [id] the primary key. */
  const SOSSessionModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'SOSSessionModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is SOSSessionModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}