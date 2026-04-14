import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:lottie/lottie.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String pdfName;
  final String userId; // Add user ID to make bookmarks user-specific

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.pdfName,
    required this.userId, // Required parameter
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  final TextEditingController _searchController = TextEditingController();
  List<Bookmark> _bookmarks = [];
  int _currentPage = 1;
  int _totalPages = 0;
  File? _pdfFile;
  bool _loading = true;
  String? _errorMessage;
  bool _isSearching = false;
  PdfTextSearchResult? _searchResult;
  int _currentSearchInstance = 0;
  int _totalSearchInstances = 0;

  // Theme colors
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color darkBlack = Color(0xFF0F172A);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color surfaceColor = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _pdfViewerController.addListener(_onPageChanged);
    _loadPdf();
    _loadBookmarks();
  }

  void _onPageChanged() {
    if (mounted) {
      setState(() {
        _currentPage = _pdfViewerController.pageNumber;
      });
    }
  }

  Future<void> _loadPdf() async {
    try {
      if (widget.pdfUrl.isEmpty || widget.pdfName.isEmpty) {
        throw Exception('Invalid PDF URL or name');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.pdfName}.pdf');

      if (!await file.exists()) {
        final ref = FirebaseStorage.instance.refFromURL(widget.pdfUrl);
        await ref.writeToFile(file);
      }

      if (mounted) {
        setState(() {
          _pdfFile = file;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Failed to load PDF: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use both userId and pdfName to create unique key per user per PDF
      final key = 'bm_${widget.userId}_${widget.pdfName.hashCode}';
      final data = prefs.getString(key);
      if (data != null && mounted) {
        final decoded = json.decode(data) as List;
        setState(() {
          _bookmarks = decoded.map((e) => Bookmark.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use both userId and pdfName to create unique key per user per PDF
      final key = 'bm_${widget.userId}_${widget.pdfName.hashCode}';
      await prefs.setString(
        key,
        json.encode(_bookmarks.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      _showSnackBar('Failed to save bookmark', isError: true);
    }
  }

  void _addBookmark() {
    if (_currentPage <= 0) {
      _showSnackBar('Invalid page number', isError: true);
      return;
    }

    final existingBookmark = _bookmarks.firstWhere(
      (b) => b.pageNumber == _currentPage,
      orElse: () => Bookmark(pageNumber: -1, title: '', timestamp: DateTime.now()),
    );

    if (existingBookmark.pageNumber != -1) {
      _showSnackBar('Bookmark already exists for this page', isError: true);
      return;
    }

    setState(() {
      _bookmarks.add(
        Bookmark(
          pageNumber: _currentPage,
          title: 'Page $_currentPage',
          timestamp: DateTime.now(),
        ),
      );
    });
    _saveBookmarks();
    _showSuccessDialog('Bookmark added successfully!');
  }

  void _removeBookmark(int index) {
    if (index < 0 || index >= _bookmarks.length) {
      _showSnackBar('Invalid bookmark', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(index),
    );
  }

  Widget _buildDeleteConfirmationDialog(int index) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkBlack, surfaceColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secondaryBlue.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/blocked.json',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Bookmark?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildGradientButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Cancel',
                    colors: [surfaceColor, surfaceColor],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGradientButton(
                    onPressed: () {
                      setState(() {
                        _bookmarks.removeAt(index);
                      });
                      _saveBookmarks();
                      Navigator.pop(context);
                      _showSnackBar('Bookmark deleted');
                    },
                    label: 'Delete',
                    colors: [Colors.red.shade700, Colors.red.shade900],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarksDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          height: 450,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [darkBlack, surfaceColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: secondaryBlue.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, secondaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmarks, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Bookmarks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _bookmarks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/lottie/empty.json',
                              width: 200,
                              height: 200,
                            ),
                            Text(
                              'No bookmarks yet',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _bookmarks.length,
                        itemBuilder: (context, index) {
                          final b = _bookmarks[index];
                          return _buildBookmarkCard(b, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(Bookmark bookmark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaceColor, primaryBlue.withOpacity(0.3)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentBlue.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [secondaryBlue, accentBlue],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.bookmark, color: Colors.white, size: 20),
        ),
        title: Text(
          bookmark.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _formatDate(bookmark.timestamp),
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
          onPressed: () {
            Navigator.pop(context);
            _removeBookmark(index);
          },
        ),
        onTap: () {
          if (bookmark.pageNumber > 0) {
            _pdfViewerController.jumpToPage(bookmark.pageNumber);
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkBlack, surfaceColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: secondaryBlue.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.search, color: accentBlue),
                    const SizedBox(width: 12),
                    Text(
                      'Search PDF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter search term...',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryBlue.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentBlue, width: 2),
                    ),
                    prefixIcon: Icon(Icons.search, color: accentBlue),
                  ),
                  onSubmitted: (_) {
                    Navigator.pop(dialogContext);
                    _performSearch();
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildGradientButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _performSearch();
                      },
                      label: 'Search',
                      colors: [secondaryBlue, accentBlue],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _performSearch() {
    final searchText = _searchController.text.trim();
    
    if (searchText.isEmpty) {
      _showSnackBar('Please enter a search term', isError: true);
      return;
    }

    // Clear previous search
    if (_searchResult != null) {
      _searchResult!.removeListener(_onSearchResultChanged);
      _searchResult!.clear();
      _searchResult = null;
    }

    setState(() {
      _isSearching = true;
      _currentSearchInstance = 0;
      _totalSearchInstances = 0;
    });

    // Start new search - this is synchronous and returns immediately
    _searchResult = _pdfViewerController.searchText(searchText);
    
    // Add listener to track search progress
    _searchResult!.addListener(_onSearchResultChanged);
    
    _showSnackBar('Searching for "$searchText"...');
  }

  void _onSearchResultChanged() {
    if (_searchResult == null || !mounted) return;

    final totalCount = _searchResult!.totalInstanceCount;
    final currentIndex = _searchResult!.currentInstanceIndex;
    final isSearchCompleted = _searchResult!.isSearchCompleted;

    setState(() {
      _totalSearchInstances = totalCount;
      _currentSearchInstance = currentIndex;
    });

    // When search completes
    if (isSearchCompleted) {
      if (totalCount > 0) {
        _showSnackBar('Found $totalCount result${totalCount > 1 ? 's' : ''}');
        
        // Auto navigate to first result if we're at index 0
        if (currentIndex == 0) {
          Future.delayed(Duration(milliseconds: 300), () {
            if (_searchResult != null && mounted) {
              _searchResult!.nextInstance();
            }
          });
        }
      } else {
        _showSnackBar('No results found', isError: true);
        _clearSearch();
      }
    }
  }

  void _clearSearch() {
    if (_searchResult != null) {
      _searchResult!.removeListener(_onSearchResultChanged);
      _searchResult!.clear();
      _searchResult = null;
    }
    _searchController.clear();
    
    if (mounted) {
      setState(() {
        _isSearching = false;
        _currentSearchInstance = 0;
        _totalSearchInstances = 0;
      });
    }
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String label,
    required List<Color> colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [darkBlack, surfaceColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lottie/Success.json',
                width: 120,
                height: 120,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : secondaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchResult?.removeListener(_onSearchResultChanged);
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlack,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBlue, secondaryBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pdfName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_loading && _errorMessage == null)
              Text(
                'Page $_currentPage',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.bookmarks),
              onPressed: _showBookmarksDialog,
              tooltip: 'Bookmarks',
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showSearchDialog,
              tooltip: 'Search',
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/lottie/loading.json',
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading PDF...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/lottie/error.json',
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildGradientButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _errorMessage = null;
                          });
                          _loadPdf();
                        },
                        label: 'Retry',
                        colors: [secondaryBlue, accentBlue],
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [darkBlack, surfaceColor.withOpacity(0.5)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: SfPdfViewer.file(
                        _pdfFile!,
                        controller: _pdfViewerController,
                        onDocumentLoaded: (details) {
                          setState(() {
                            _totalPages = details.document.pages.count;
                          });
                        },
                      ),
                    ),
                    if (_isSearching && _totalSearchInstances > 0)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryBlue, secondaryBlue],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_upward, color: Colors.white),
                                  onPressed: () {
                                    _searchResult?.previousInstance();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '$_currentSearchInstance / $_totalSearchInstances',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: Icon(Icons.arrow_downward, color: Colors.white),
                                  onPressed: () {
                                    _searchResult?.nextInstance();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.white),
                                  onPressed: _clearSearch,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: _loading || _errorMessage != null
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [secondaryBlue, accentBlue],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: secondaryBlue.withOpacity(0.5),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _addBookmark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.bookmark_add, size: 28),
              ),
            ),
    );
  }
}

class Bookmark {
  final int pageNumber;
  final String title;
  final DateTime timestamp;

  Bookmark({
    required this.pageNumber,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      pageNumber: json['pageNumber'] ?? 0,
      title: json['title'] ?? 'Untitled',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}