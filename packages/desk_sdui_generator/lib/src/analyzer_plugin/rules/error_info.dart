class AnalysisErrorInfo {
  AnalysisErrorInfo(this.offset, this.length, this.code, this.message);
  final int offset;
  final int length;
  final String code;
  final String message;
}
