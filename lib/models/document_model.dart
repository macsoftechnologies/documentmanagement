class DocumentModel {
  final int userDocumentId;
   final String userName; 
  final String documentName;
  final String price;
  final String startDate;
  final String endDate;
  final String status;

  DocumentModel({
    required this.userDocumentId,
     required this.userName,
    required this.documentName,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      userDocumentId: int.parse(json['user_document_id'].toString()),

      documentName:   json['document_name'] ?? '',
      userName:       json['user_name'] ?? '',

      price:          json['price'].toString(),
      startDate:      json['start_date'] ?? '',
      endDate:        json['end_date'] ?? '',
      status:         json['status'] ?? '',
    );
  }
}