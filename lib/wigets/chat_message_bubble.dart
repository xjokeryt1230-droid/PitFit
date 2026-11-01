
import 'package:flutter/material.dart';

const Color pitFitYellow = Color(0xFFFFD54F);
const Color pitFitNavy = Color(0xFF101827);
const Color pitFitCard = Color(0xFF1C2738);

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.timestamp,
    required this.isMine,
  });

  final String text;
  final DateTime timestamp;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isMine ? pitFitYellow : pitFitCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 5),
                  bottomRight: Radius.circular(isMine ? 5 : 18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMine ? pitFitNavy : Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              time,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
