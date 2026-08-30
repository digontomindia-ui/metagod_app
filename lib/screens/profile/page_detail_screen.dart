import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../theme/app_colors.dart';

class PageDetailScreen extends StatelessWidget {
  final String title;
  final String content;

  const PageDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24, 
          right: 24, 
          top: 20, 
          bottom: 20 + MediaQuery.of(context).padding.bottom,
        ),
        child: HtmlWidget(
          // Forcefully strip all black/dark colors and set them to cream
          content.replaceAll(RegExp(r'(?<!-)(color\s*:\s*[^;"]+;?)', caseSensitive: false), 'color: #FFF2D9;')
                 .replaceAll(RegExp(r'background-color\s*:\s*[^;"]+;?', caseSensitive: false), 'background-color: transparent;')
                 .replaceAll(RegExp(r'background\s*:\s*[^;"]+;?', caseSensitive: false), 'background: transparent;'),
          textStyle: const TextStyle(
            color: AppColors.cream,
            fontSize: 16,
            height: 1.6,
            letterSpacing: 0.3,
          ),
          customStylesBuilder: (element) {
            // Strip any hardcoded backgrounds and force text colors to light theme
            final styles = <String, String>{
              'background-color': 'transparent',
              'background': 'transparent',
              'color': '#FFF2D9', // AppColors.cream
            };
            
            if (element.localName == 'a') {
              styles['color'] = '#FFD700';
              styles['text-decoration'] = 'none';
              styles['font-weight'] = 'bold';
            } else if (element.localName == 'h1' || element.localName == 'h2') {
              styles['color'] = '#FFD700';
              styles['font-weight'] = '800';
              styles['margin-top'] = '1em';
              styles['margin-bottom'] = '0.5em';
            } else if (element.localName == 'h3' || element.localName == 'h4') {
              styles['color'] = '#FFFFFF';
              styles['font-weight'] = '700';
              styles['margin-top'] = '1em';
              styles['margin-bottom'] = '0.5em';
            } else if (element.localName == 'p') {
              styles['margin-bottom'] = '1em';
            } else if (element.localName == 'li') {
              styles['margin-bottom'] = '0.5em';
            }
            
            return styles;
          },
        ),
      ),
    );
  }
}
