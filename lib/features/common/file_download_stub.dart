/// Browser downloads exist only on web; other platforms use the share sheet.
void downloadTextFile(String fileName, String content) =>
    throw UnsupportedError('Downloads are only available on web');
