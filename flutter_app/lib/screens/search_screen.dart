// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import 'job_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final ApiService api;
  const SearchScreen({super.key, required this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Job> _results = [];
  bool _isSearching = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    widget.api.getSavedUserId().then((id) => setState(() => _userId = id));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) return;
    setState(() => _isSearching = true);
    final results = await widget.api.searchJobs(query);
    setState(() { _results = results; _isSearching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onSubmitted: _search,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search: railway, police, SSC...',
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
            fillColor: Colors.transparent,
            filled: false,
          ),
          cursorColor: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptySearch()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) => JobCard(
                    job: _results[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => JobDetailScreen(
                        jobId: _results[i].id,
                        api: widget.api,
                        userId: _userId ?? 0,
                      )),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text('Koi bhi job search karo',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          const Text('Railway, Police, SSC, Bank...'),
        ],
      ),
    );
  }
}
