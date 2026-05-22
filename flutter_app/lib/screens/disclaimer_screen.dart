import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  static const _sources = <_Source>[
    _Source('SSC (Staff Selection Commission)', 'https://ssc.gov.in'),
    _Source('UPSC (Union Public Service Commission)', 'https://upsc.gov.in'),
    _Source('IBPS (Banking Personnel Selection)', 'https://ibps.in'),
    _Source('SBI Careers', 'https://sbi.co.in/careers'),
    _Source('Reserve Bank of India (RBI)', 'https://rbi.org.in'),
    _Source('RRB (Railway Recruitment Board)', 'https://rrbcdg.gov.in'),
    _Source('Indian Railways', 'https://indianrailways.gov.in'),
    _Source('DRDO', 'https://drdo.gov.in'),
    _Source('ISRO', 'https://isro.gov.in'),
    _Source('AIIMS', 'https://aiims.edu'),
    _Source('KVS (Kendriya Vidyalaya Sangathan)', 'https://kvsangathan.nic.in'),
    _Source('NVS (Navodaya Vidyalaya Samiti)', 'https://navodaya.gov.in'),
    _Source('BSF (Border Security Force)', 'https://bsf.gov.in'),
    _Source('CRPF (Central Reserve Police Force)', 'https://crpf.gov.in'),
    _Source('BHEL', 'https://bhel.com'),
    _Source('ONGC', 'https://ongcindia.com'),
    _Source('NTPC', 'https://ntpc.co.in'),
    _Source('GAIL India', 'https://gailonline.com'),
    _Source('India Post', 'https://indiapost.gov.in'),
    _Source('National Career Service', 'https://ncs.gov.in'),
    _Source('FreeJobAlert (aggregator)', 'https://freejobalert.com'),
    _Source('Sarkari Result (aggregator)', 'https://sarkariresult.com'),
  ];

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Disclaimer & Sources'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF9933), width: 1.5),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFE65100), size: 22),
                    SizedBox(width: 8),
                    Text('Important Disclaimer',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100))),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'JobMitra is an independent third-party app. It is NOT affiliated with, '
                  'endorsed by, sponsored by, or operated by the Government of India, '
                  'any State Government, or any government entity, department, '
                  'recruitment board, public sector undertaking (PSU), or ministry.\n\n'
                  'JobMitra does NOT facilitate, process, or guarantee any government '
                  'job application, admit card, result, or recruitment outcome. The app '
                  'aggregates publicly available information from official government '
                  'websites and other publicly accessible sources, and displays it for '
                  'informational and reference purposes only.\n\n'
                  'For applying to any government job or verifying official information, '
                  'users must visit the original official source listed below or use the '
                  '"View Original" link inside each job post. JobMitra makes no '
                  'guarantee about the accuracy, completeness, or timeliness of any '
                  'information displayed in the app.',
                  style: TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF333333)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Official Source Websites',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'All government information shown in JobMitra is sourced from these '
              'official portals. Tap any source to visit the official website.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < _sources.length; i++) ...[
                  InkWell(
                    onTap: () => _open(_sources[i].url),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.public,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_sources[i].name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(_sources[i].url,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1565C0))),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new,
                              size: 16, color: Colors.grey[500]),
                        ],
                      ),
                    ),
                  ),
                  if (i < _sources.length - 1)
                    const Divider(height: 1, indent: 42),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Trademarks, logos, and brand names of government entities and '
              'recruitment boards mentioned in this app are the property of their '
              'respective owners. Their use in JobMitra does not imply any '
              'affiliation, endorsement, or sponsorship.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _Source {
  final String name;
  final String url;
  const _Source(this.name, this.url);
}
