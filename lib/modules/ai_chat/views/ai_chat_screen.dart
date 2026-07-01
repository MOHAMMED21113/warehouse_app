// lib/presentation/screens/ai_chat_screen.dart
import 'package:flutter/material.dart';
import '../../../core/providers/global_providers.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_colors.dart';
import '../../../database/database_helper.dart';
import '../../../domain/usecases/ai_chat_usecase.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showSuggestions = true;
  late AiChatUseCase _chatUseCase;

  // ===== أسئلة مقترحة =====
  static const List<Map<String, dynamic>> _suggestions = [
    {'icon': Icons.trending_up_rounded, 'text': 'كم إجمالي مبيعات اليوم؟', 'color': Color(0xFF10B981)},
    {'icon': Icons.inventory_2_rounded, 'text': 'ما هي المنتجات الأكثر مبيعاً؟', 'color': Color(0xFF60A5FA)},
    {'icon': Icons.warning_amber_rounded, 'text': 'ما المنتجات منخفضة المخزون؟', 'color': Color(0xFFF59E0B)},
    {'icon': Icons.people_rounded, 'text': 'من هم أكبر العملاء المدينين؟', 'color': Color(0xFFF97316)},
    {'icon': Icons.lightbulb_outline_rounded, 'text': 'اقترح تصنيف لمنتج', 'color': Color(0xFFD4AF37)},
    {'icon': Icons.account_balance_rounded, 'text': 'كم رصيد الخزينة الحالي؟', 'color': Color(0xFF818CF8)},
  ];

  @override
  void initState() {
    super.initState();
    _chatUseCase = AiChatUseCase(DatabaseHelper.instance);

    // رسالة ترحيبية
    _messages.add(_ChatMessage(
      text: 'أهلاً بك! 👋\nأنا المساعد الذكي لنظام المخازن. اسألني عن المبيعات، المخزون، أو اطلب مني اقتراح تصنيفات للمنتجات الجديدة وسأقوم بإنشائها لك بنقرة زر.',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ==================== إرسال الرسالة ====================
  Future<void> _sendMessage([String? customText]) async {
    final text = customText ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _isLoading = true;
      _showSuggestions = false;
    });

    if (customText == null) _controller.clear();
    _scrollToBottom();

    try {
      final response = await _chatUseCase.processUserQuery(text);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: response, isUser: false, time: DateTime.now()));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: '❌ حدث خطأ أثناء المعالجة. يرجى المحاولة مرة أخرى.',
            isUser: false,
            time: DateTime.now(),
            isError: true,
          ));
          _isLoading = false;
        });
      }
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم نسخ الرسالة', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearChat(Color cardBg, Color textMain, Color textSub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          Text('مسح المحادثة', style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text('هل تريد مسح جميع الرسائل؟', style: TextStyle(color: textSub, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(color: textSub))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add(_ChatMessage(
                  text: 'أهلاً بك! 👋\nأنا المساعد الذكي لنظام المخازن. كيف يمكنني مساعدتك؟',
                  isUser: false,
                  time: DateTime.now(),
                ));
                _showSuggestions = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('مسح', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==================== البناء الرئيسي ====================
  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // 🚀 جلب الثيم والحالة عبر Riverpod
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // الألوان المتكيفة
    final scaffoldBg = isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9);
    final cardBg = isDark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppColors.darkTextPrimary : AppColors.navy;
    final textSub = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final textHint = isDark ? AppColors.darkTextHint : const Color(0xFF94A3B8);
    final inputFill = isDark ? AppColors.navyLight : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildAppBar(isDark, cardBg, textMain, textSub),
      body: Column(
        children: [
          Expanded(child: _buildChatArea(isDark, cardBorder, textMain, textHint)),

          if (_isLoading) _buildTypingIndicator(cardBg, cardBorder, textHint),

          Visibility(
            visible: _showSuggestions && _messages.length <= 1 && !isKeyboardOpen,
            child: _buildSuggestions(isDark, textSub),
          ),

          _buildInputBar(isKeyboardOpen, isDark, inputFill, cardBorder, textMain, textHint),
        ],
      ),
    );
  }

  // ==================== AppBar ====================
  PreferredSizeWidget _buildAppBar(bool isDark, Color cardBg, Color textMain, Color textSub) {
    return AppBar(
      backgroundColor: isDark ? AppColors.navyMedium : AppColors.navy,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5D76E)]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.psychology_rounded, color: AppColors.navy, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('المساعد الذكي', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('متصل الآن', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
          ],
        ),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.primary, size: 22),
          onPressed: () => _clearChat(cardBg, textMain, textSub),
          tooltip: 'مسح المحادثة',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.navy, AppColors.primary.withOpacity(0.6), AppColors.navy]),
          ),
        ),
      ),
    );
  }

  // ==================== منطقة الشات ====================
  Widget _buildChatArea(bool isDark, Color cardBorder, Color textMain, Color textHint) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index == _messages.length - 1 ? 200 : 0)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildMessageBubble(msg, isDark, cardBorder, textMain, textHint),
        );
      },
    );
  }

  // ==================== فقاعة الرسالة (مع الزر السحري) ====================
  Widget _buildMessageBubble(_ChatMessage msg, bool isDark, Color cardBorder, Color textMain, Color textHint) {
    final isUser = msg.isUser;
    final timeStr = DateFormat('hh:mm a', 'ar').format(msg.time);

    // 💡 التحليل السحري: استخراج كود التوليد وإخفاؤه
    String displayText = msg.text;
    Match? createMatch;

    if (!isUser) {
      final regex = RegExp(r'\[CREATE_CLASS\|(.*?)\|(.*?)\|(.*?)\]');
      createMatch = regex.firstMatch(msg.text);
      if (createMatch != null) {
        displayText = msg.text.replaceAll(regex, '').trim();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const SizedBox(width: 4),
            _buildAvatar(isUser: false),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyMessage(displayText),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  color: isUser
                      ? (isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primary.withOpacity(0.1))
                      : (isDark ? AppColors.navyCard : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 4 : 18),
                    bottomRight: Radius.circular(isUser ? 18 : 4),
                  ),
                  border: Border.all(
                    color: msg.isError
                        ? AppColors.error.withOpacity(0.4)
                        : isUser
                        ? AppColors.primary.withOpacity(0.3)
                        : cardBorder,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? AppColors.primary : Colors.black).withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      displayText,
                      style: TextStyle(
                        fontSize: 14,
                        color: msg.isError ? AppColors.error : textMain,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),

                    if (createMatch != null) ...[
                      const SizedBox(height: 12),
                      _buildMagicCreateButton(
                          createMatch.group(1)!,
                          createMatch.group(2)!,
                          createMatch.group(3)!,
                          isDark
                      ),
                    ],

                    const SizedBox(height: 6),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(timeStr, style: TextStyle(fontSize: 9, color: textHint)),
                        if (!isUser) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _copyMessage(displayText),
                            child: Icon(Icons.copy_rounded, size: 12, color: textHint),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(isUser: true),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  // ==================== الزر السحري للإنشاء ====================
  Widget _buildMagicCreateButton(String group, String category, String subcategory, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // 1. عرض دائرة التحميل عبر showDialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            );

            // 2. استدعاء الدالة السحرية من قاعدة البيانات
            final res = await DatabaseHelper.instance.autoCreateClassificationTree(
                group, category, subcategory
            );

            // 3. إغلاق دائرة التحميل
            if (mounted) Navigator.pop(context);

            if (!mounted) return;

            // 4. إظهار النتيجة للمستخدم عبر ScaffoldMessenger
            if (res['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'], style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(12),
                    duration: const Duration(seconds: 4),
                  )
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'], style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(12),
                  )
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(height: 6),
                const Text(
                  'إنشاء التصنيف تلقائياً',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '($group > $category > $subcategory)',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.navy.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5D76E)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'تأكيد وإنشاء 🚀',
                    style: TextStyle(color: Color(0xFF0A1628), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)])
            : const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5D76E)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUser ? const Color(0xFF60A5FA).withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.psychology_rounded,
        color: isUser ? Colors.white : AppColors.navy,
        size: 16,
      ),
    );
  }

  // ==================== مؤشر الكتابة ====================
  Widget _buildTypingIndicator(Color cardBg, Color cardBorder, Color textHint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _buildAvatar(isUser: false),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TypingDot(delay: 0, color: AppColors.primary),
                const SizedBox(width: 4),
                const _TypingDot(delay: 150, color: AppColors.primary),
                const SizedBox(width: 4),
                const _TypingDot(delay: 300, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('يكتب...', style: TextStyle(fontSize: 11, color: textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== الأسئلة المقترحة ====================
  Widget _buildSuggestions(bool isDark, Color textSub) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 4),
            child: Row(children: [
              const Icon(Icons.lightbulb_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('أسئلة مقترحة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSub)),
            ]),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions.map((s) => _buildSuggestionChip(s, isDark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(Map<String, dynamic> suggestion, bool isDark) {
    final Color color = suggestion['color'] as Color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _sendMessage(suggestion['text'] as String),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.08) : color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(suggestion['icon'] as IconData, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  suggestion['text'] as String,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== شريط الإدخال ====================
  Widget _buildInputBar(bool isKeyboardOpen, bool isDark, Color inputFill, Color cardBorder, Color textMain, Color textHint) {
    final double safeBottomPadding = isKeyboardOpen
        ? 10
        : MediaQuery.of(context).padding.bottom + 10;

    return Container(
      key: const ValueKey('chat_input_bar'),
      padding: EdgeInsets.fromLTRB(12, 10, 12, safeBottomPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyMedium : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.primary.withOpacity(0.15) : cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: isDark ? AppColors.primary.withOpacity(0.2) : cardBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textDirection: TextDirection.rtl,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: textMain, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اسأل المساعد الذكي...',
                  hintStyle: TextStyle(color: textHint, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.psychology_alt_rounded, color: textHint, size: 20),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),

          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? LinearGradient(colors: [textHint.withOpacity(0.3), textHint.withOpacity(0.2)])
                        : const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5D76E)]),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _isLoading
                        ? null
                        : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _isLoading ? textHint : AppColors.navy,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== نموذج الرسالة ====================
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isError = false,
  });
}

// ==================== أنيميشن نقاط الكتابة ====================
class _TypingDot extends StatefulWidget {
  final int delay;
  final Color color;

  const _TypingDot({required this.delay, required this.color});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _anim.value),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.4 + (0.6 * _anim.value)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}