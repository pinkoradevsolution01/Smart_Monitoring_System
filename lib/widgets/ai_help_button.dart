import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/ai_help_service.dart';
import '../models/chat_message.dart';
import '../utils/locale_controller.dart';

/// Opens the AI Help chat dialog
void showAIHelpDialog(BuildContext context) {
  final assistant = GetIt.I<AIHelpService>();
  if (assistant.isSmartPlusMode) assistant.startHelp();
  showDialog(context: context, builder: (context) => const _AIHelpDialog());
}

/// Opens the data-backed SmartPlus mode of the existing assistant.
/// SmartPlus is rule based and keeps data on the device; it is not a remote AI
/// integration and cannot execute sales, orders, or other business changes.
void showSmartPlusDialog(BuildContext context) {
  GetIt.I<AIHelpService>().startSmartPlus();
  showDialog(
    context: context,
    builder: (context) => const _AIHelpDialog(smartPlus: true),
  );
}

/// Floating AI Help Button that opens chat interface
class AIHelpButton extends StatelessWidget {
  const AIHelpButton({super.key});

  void _openHelpChat(BuildContext context) {
    showAIHelpDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _openHelpChat(context),
      backgroundColor: Theme.of(context).colorScheme.primary,
      tooltip: 'AI Help Assistant',
      child: const Icon(Icons.support_agent, color: Colors.white),
    );
  }
}

/// AI Help Chat Dialog
class _AIHelpDialog extends StatefulWidget {
  final bool smartPlus;

  const _AIHelpDialog({this.smartPlus = false});

  @override
  State<_AIHelpDialog> createState() => _AIHelpDialogState();
}

class _AIHelpDialogState extends State<_AIHelpDialog> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final AIHelpService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = GetIt.I<AIHelpService>();
    _aiService.addListener(_onAssistantChanged);
  }

  @override
  void dispose() {
    _aiService.removeListener(_onAssistantChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAssistantChanged() => _scrollToBottom();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _aiService.isThinking) return;

    _aiService.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _sendSuggestedQuestion(String question) {
    if (_aiService.isThinking) return;
    _aiService.sendMessage(question);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.smartPlus
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final media = MediaQuery.sizeOf(context);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = media.height - keyboardHeight - 48;
    final dialogHeight = availableHeight > 700 ? 700.0 : availableHeight;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: media.width > 632 ? 600 : media.width - 32,
        height: dialogHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor.withValues(alpha: 0.05), Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.smartPlus
                          ? Icons.auto_awesome_rounded
                          : Icons.support_agent,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<Locale>(
                      valueListenable: LocaleController.locale,
                      builder: (context, locale, _) {
                        final isFilipino = locale.languageCode == 'fil';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.smartPlus
                                  ? 'SmartPlus'
                                  : (isFilipino
                                        ? 'AI Tulong Assistant'
                                        : 'AI Help Assistant'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.smartPlus
                                  ? (isFilipino
                                        ? 'Rule-based na sales at inventory insights'
                                        : 'Rule-based sales and inventory insights')
                                  : (isFilipino
                                        ? 'Magtanong tungkol sa sistema'
                                        : 'Ask me anything about the system'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: LocaleController.locale.value.languageCode == 'fil'
                        ? 'I-clear ang usapan'
                        : 'Clear conversation',
                    onPressed: () {
                      _aiService.clearMessages();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListenableBuilder(
                listenable: _aiService,
                builder: (context, _) {
                  final messages = _aiService.messages;
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length +
                        (widget.smartPlus && _aiService.isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const _SmartPlusThinkingBubble();
                      }
                      final message = messages[index];
                      return _MessageBubble(message: message);
                    },
                  );
                },
              ),
            ),

            // Suggested Questions
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListenableBuilder(
                listenable: _aiService,
                builder: (context, _) {
                  // Show suggestions only if conversation is short
                  if (_aiService.messages.length > 3) {
                    return const SizedBox.shrink();
                  }

                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _aiService.getSuggestedQuestions().length,
                      itemBuilder: (context, index) {
                        final question = _aiService
                            .getSuggestedQuestions()[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              question,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onPressed: () => _sendSuggestedQuestion(question),
                            backgroundColor: primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Input Field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<Locale>(
                      valueListenable: LocaleController.locale,
                      builder: (context, locale, _) {
                        final isFilipino = locale.languageCode == 'fil';
                        return TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: isFilipino
                                ? 'I-type ang iyong tanong...'
                                : 'Type your question...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated typing state displayed only while SmartPlus is evaluating a rule.
class _SmartPlusThinkingBubble extends StatefulWidget {
  const _SmartPlusThinkingBubble();

  @override
  State<_SmartPlusThinkingBubble> createState() =>
      _SmartPlusThinkingBubbleState();
}

class _SmartPlusThinkingBubbleState extends State<_SmartPlusThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(int index, Color color) {
    final begin = index * 0.18;
    final end = (begin + 0.5).clamp(0.0, 1.0).toDouble();
    final animation = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeInOut),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, animation.value),
        child: child,
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 20, color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SmartPlus is thinking',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 9),
                _dot(0, color),
                const SizedBox(width: 4),
                _dot(1, color),
                const SizedBox(width: 4),
                _dot(2, color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual message bubble
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy, size: 20, color: primaryColor),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 20, color: primaryColor),
            ),
          ],
        ],
      ),
    );
  }
}
