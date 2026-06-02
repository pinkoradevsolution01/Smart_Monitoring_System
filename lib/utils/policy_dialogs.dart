import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// Utility class for showing Privacy Policy and User Agreement dialogs
class PolicyDialogs {
  /// Show Privacy Policy dialog
  static void showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.privacy_tip,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.t('privacy_policy'))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('privacy_last_updated'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  AppLocalizations.t('privacy_intro_title'),
                  AppLocalizations.t('privacy_intro_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('privacy_data_collection_title'),
                  AppLocalizations.t('privacy_data_collection_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('privacy_data_usage_title'),
                  AppLocalizations.t('privacy_data_usage_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('privacy_data_storage_title'),
                  AppLocalizations.t('privacy_data_storage_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('privacy_security_title'),
                  AppLocalizations.t('privacy_security_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('privacy_rights_title'),
                  AppLocalizations.t('privacy_rights_content'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  /// Show User Agreement dialog
  static void showUserAgreement(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.description,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.t('user_agreement'))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('agreement_last_updated'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  AppLocalizations.t('agreement_acceptance_title'),
                  AppLocalizations.t('agreement_acceptance_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('agreement_license_title'),
                  AppLocalizations.t('agreement_license_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('agreement_restrictions_title'),
                  AppLocalizations.t('agreement_restrictions_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('agreement_responsibilities_title'),
                  AppLocalizations.t('agreement_responsibilities_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('agreement_liability_title'),
                  AppLocalizations.t('agreement_liability_content'),
                ),
                _buildSection(
                  context,
                  AppLocalizations.t('agreement_termination_title'),
                  AppLocalizations.t('agreement_termination_content'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  /// Helper method to build sections in the dialogs
  static Widget _buildSection(
    BuildContext context,
    String title,
    String content,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}
