import 'package:flutter/material.dart';

class TermsPoliciesPage extends StatelessWidget {
  const TermsPoliciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFCE7ED6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms & Privacy Policy',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Last Updated
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: purple.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Last Updated: August 3, 2025',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: purple,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Terms of Service Section
            _buildSectionTitle('Terms of Service'),
            const SizedBox(height: 15),
            
            _buildSubsection('1. Acceptance of Terms', 
              'By downloading, installing, or using our mobile application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our app.'),
            
            _buildSubsection('2. Description of Service', 
              'Our app provides users with a platform to manage personal information, connect with others, and access various features. We reserve the right to modify, suspend, or discontinue any part of our service at any time.'),
            
            _buildSubsection('3. User Accounts', 
              'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.'),
            
            _buildSubsection('4. Acceptable Use', 
              'You agree not to use our app for any unlawful purposes or in any way that could damage, disable, or impair our service. Prohibited activities include harassment, spam, or uploading malicious content.'),
            
            _buildSubsection('5. Intellectual Property', 
              'All content, features, and functionality of our app are owned by us and are protected by copyright, trademark, and other intellectual property laws.'),
            
            const SizedBox(height: 40),
            
            // Privacy Policy Section
            _buildSectionTitle('Privacy Policy'),
            const SizedBox(height: 15),
            
            _buildSubsection('1. Information We Collect', 
              'We collect information you provide directly to us, such as when you create an account, update your profile, or contact us for support. This may include your name, email address, and other personal information.'),
            
            _buildSubsection('2. How We Use Your Information', 
              'We use the information we collect to provide, maintain, and improve our services, communicate with you, and ensure the security of our platform.'),
            
            _buildSubsection('3. Information Sharing', 
              'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy or as required by law.'),
            
            _buildSubsection('4. Data Security', 
              'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.'),
            
            _buildSubsection('5. Data Retention', 
              'We retain your personal information for as long as necessary to provide our services and comply with legal obligations. You may request deletion of your account and associated data at any time.'),
            
            _buildSubsection('6. Your Rights', 
              'You have the right to access, update, or delete your personal information. You may also opt out of certain communications from us.'),
            
            const SizedBox(height: 40),
            
            // Contact Information
            _buildSectionTitle('Contact Us'),
            const SizedBox(height: 15),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'If you have any questions about these Terms and Privacy Policy, please contact us:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildContactItem(Icons.email, 'support@yourapp.com'),
                  const SizedBox(height: 10),
                  _buildContactItem(Icons.phone, '+1 (555) 123-4567'),
                  const SizedBox(height: 10),
                  _buildContactItem(Icons.location_on, '123 App Street, Tech City, TC 12345'),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Agreement Notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade600,
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Important Notice',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By continuing to use our app, you acknowledge that you have read, understood, and agree to be bound by these Terms and Privacy Policy.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFCE7ED6),
      ),
    );
  }

  Widget _buildSubsection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFFCE7ED6),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}