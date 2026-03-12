// lib/screens/saved_jobs_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import 'job_detail_screen.dart';

class SavedJobsScreen extends StatefulWidget {
  final int userId;
  final ApiService api;
  const SavedJobsScreen({super.key, required this.userId, required this.api});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<Job> _savedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedJobs();
  }

  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    final jobs = await widget.api.getSavedJobs(widget.userId);
    setState(() { _savedJobs = jobs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Jobs')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedJobs.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedJobs.length,
                  itemBuilder: (ctx, i) => JobCard(
                    job: _savedJobs[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => JobDetailScreen(
                        jobId: _savedJobs[i].id,
                        api: widget.api,
                        userId: widget.userId,
                      )),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔖', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text('Koi saved job nahi',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          const Text('Job detail mein bookmark icon dabaao'),
        ],
      ),
    );
  }
}
