/// 导入进度状态
enum ImportProgressState {
  picking, // 选择文件
  validating, // 校验
  copying, // 复制文件
  decoding, // 解码文本（仅 TXT）
  saving, // 保存记录
  done, // 完成
  error, // 出错
}

/// 导入进度通知
class ImportProgress {
  const ImportProgress({required this.state, this.message});
  final ImportProgressState state;
  final String? message;

  ImportProgress copyWith({ImportProgressState? state, String? message}) =>
      ImportProgress(
        state: state ?? this.state,
        message: message ?? this.message,
      );
}

/// 导入阶段文案（中文）
extension ImportProgressStateX on ImportProgressState {
  String get label {
    switch (this) {
      case ImportProgressState.picking:
        return '请选择文件';
      case ImportProgressState.validating:
        return '正在校验文件';
      case ImportProgressState.copying:
        return '正在复制文件到本地';
      case ImportProgressState.decoding:
        return '正在识别编码';
      case ImportProgressState.saving:
        return '正在保存书籍';
      case ImportProgressState.done:
        return '导入完成';
      case ImportProgressState.error:
        return '导入失败';
    }
  }
}
