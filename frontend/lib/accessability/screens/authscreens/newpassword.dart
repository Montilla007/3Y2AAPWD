import 'package:flutter/material.dart';
import 'package:frontend/accessability/widgets/accessabilityheader.dart';
import 'package:frontend/accessability/widgets/authwidgets/newpasswordform.dart';

class Newpassword extends StatelessWidget {
  const Newpassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isOverflowing = constraints.maxHeight < 600;

            return SingleChildScrollView(
              physics: isOverflowing
                  ? AlwaysScrollableScrollPhysics()
                  : NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  const Accessabilityheader(),
                  const SizedBox(height: 70),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Newpasswordform(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}