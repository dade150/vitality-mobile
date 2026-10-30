import 'package:flutter/material.dart';

/// Widget per il rendering formattato e accessibile dei messaggi di chat.
/// Gestisce automaticamente la sintassi Markdown comune usata dai modelli LLM:
/// - Grassetto: `**testo**`
/// - Elenchi puntati: righe che iniziano con `* `, `- ` o `• `
/// - Elenchi numerati: righe che iniziano con `1. `, `2. `, etc.
/// - Paragrafi e interruzioni di riga
///
/// È completamente resiliente allo streaming parziale (es. `**` non ancora chiuso).
class FormattedChatMessage extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool isUser;

  const FormattedChatMessage({
    super.key,
    required this.text,
    this.style,
    this.isUser = false,
  });

  static final _bulletRegex = RegExp(r'^\s*[\*\-•]\s+(.*)$');
  static final _numberedRegex = RegExp(r'^\s*(\d+[\.\)])\s+(.*)$');
  static final _boldPattern = RegExp(r'\*\*(.*?)(?:\*\*|$)');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ??
        theme.textTheme.bodyLarge?.copyWith(
          color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          height: 1.45,
        ) ??
        TextStyle(
          color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          fontSize: 16,
          height: 1.45,
        );

    final rawLines = text.split('\n');
    final blocks = _parseBlocks(rawLines);

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (blocks.length == 1 && blocks.first.type == _BlockType.paragraph) {
      return Text.rich(
        TextSpan(children: _parseInlineSpans(blocks.first.text, baseStyle)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _buildBlock(context, blocks[i], baseStyle),
          if (i < blocks.length - 1)
            SizedBox(
              height: (blocks[i].type == _BlockType.bullet ||
                      blocks[i].type == _BlockType.numbered) &&
                      (blocks[i + 1].type == _BlockType.bullet ||
                          blocks[i + 1].type == _BlockType.numbered)
                  ? 6.0
                  : 10.0,
            ),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, _Block block, TextStyle baseStyle) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bulletColor = isUser ? cs.onPrimary : cs.primary;

    switch (block.type) {
      case _BlockType.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0, left: 2.0),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: bulletColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: _parseInlineSpans(block.text, baseStyle)),
              ),
            ),
          ],
        );

      case _BlockType.numbered:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Text(
                block.prefix ?? '',
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: bulletColor,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: _parseInlineSpans(block.text, baseStyle)),
              ),
            ),
          ],
        );

      case _BlockType.paragraph:
        return Text.rich(
          TextSpan(children: _parseInlineSpans(block.text, baseStyle)),
        );
    }
  }

  List<_Block> _parseBlocks(List<String> rawLines) {
    final blocks = <_Block>[];
    String? currentParagraph;
    bool inListContinuation = false;

    void flushParagraph() {
      if (currentParagraph != null && currentParagraph!.trim().isNotEmpty) {
        blocks.add(_Block(type: _BlockType.paragraph, text: currentParagraph!));
        currentParagraph = null;
      }
    }

    for (final rawLine in rawLines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        flushParagraph();
        inListContinuation = false;
        continue;
      }

      final bulletMatch = _bulletRegex.firstMatch(line);
      if (bulletMatch != null) {
        flushParagraph();
        blocks.add(
          _Block(
            type: _BlockType.bullet,
            text: bulletMatch.group(1) ?? '',
          ),
        );
        inListContinuation = true;
        continue;
      }

      final numberedMatch = _numberedRegex.firstMatch(line);
      if (numberedMatch != null) {
        flushParagraph();
        blocks.add(
          _Block(
            type: _BlockType.numbered,
            prefix: numberedMatch.group(1),
            text: numberedMatch.group(2) ?? '',
          ),
        );
        inListContinuation = true;
        continue;
      }

      // Se la riga è la continuazione di un elemento di lista precedente
      if (inListContinuation && blocks.isNotEmpty) {
        final last = blocks.last;
        if (last.type == _BlockType.bullet || last.type == _BlockType.numbered) {
          blocks[blocks.length - 1] = _Block(
            type: last.type,
            prefix: last.prefix,
            text: '${last.text} ${line.trim()}',
          );
          continue;
        }
      }

      inListContinuation = false;
      // Se la riga fa parte di un paragrafo in corso
      if (currentParagraph == null) {
        currentParagraph = line.trim();
      } else {
        currentParagraph = '$currentParagraph ${line.trim()}';
      }
    }

    flushParagraph();
    return blocks;
  }

  List<InlineSpan> _parseInlineSpans(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final matches = _boldPattern.allMatches(text);
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final boldContent = match.group(1);
      if (boldContent != null && boldContent.isNotEmpty) {
        spans.add(
          TextSpan(
            text: boldContent,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }
}

enum _BlockType { paragraph, bullet, numbered }

class _Block {
  final _BlockType type;
  final String text;
  final String? prefix;

  _Block({required this.type, required this.text, this.prefix});
}
