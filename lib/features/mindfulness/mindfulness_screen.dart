import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

/// Mindfulness — curated links for music, videos, guided meditation, breathing exercises.
class MindfulnessScreen extends StatelessWidget {
  const MindfulnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Mindfulness')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [kPrimary.withAlpha(15), kSleep.withAlpha(15)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: kPrimary.withAlpha(20), shape: BoxShape.circle),
                child: const Icon(Icons.self_improvement, color: kPrimary, size: 26)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Take a moment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
                Text('Explore mindfulness resources to support your wellbeing',
                  style: TextStyle(fontSize: 12, color: kTextLight)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Guided Meditation ──
          _Section(title: 'Guided Meditation', icon: Icons.spa, color: kPrimary, resources: const [
            _Resource('Headspace — Basics', 'Free 10-day beginner course', 'https://www.headspace.com/meditation/meditation-for-beginners', Icons.play_circle_outline),
            _Resource('Smiling Mind', 'Free Australian mindfulness app', 'https://www.smilingmind.com.au', Icons.play_circle_outline),
            _Resource('Insight Timer', 'Free guided meditations', 'https://insighttimer.com', Icons.play_circle_outline),
            _Resource('UCLA Mindful', 'Free guided meditations from UCLA', 'https://www.uclahealth.org/programs/marc/free-guided-meditations', Icons.play_circle_outline),
          ]),
          const SizedBox(height: 14),

          // ── Breathing Exercises ──
          _Section(title: 'Breathing Exercises', icon: Icons.air, color: kEnergy, resources: const [
            _Resource('Box Breathing (4-4-4-4)', 'Calm anxiety in 4 minutes', 'https://www.healthline.com/health/box-breathing', Icons.timer),
            _Resource('4-7-8 Breathing', 'Fall asleep faster', 'https://www.healthline.com/health/4-7-8-breathing', Icons.timer),
            _Resource('Belly Breathing', 'Simple deep breathing guide', 'https://www.verywellmind.com/diaphragmatic-breathing-2584115', Icons.timer),
          ]),
          const SizedBox(height: 14),

          // ── Relaxation Music ──
          _Section(title: 'Relaxation Music', icon: Icons.music_note, color: kSleep, resources: const [
            _Resource('Calm Radio', 'Free relaxation channels', 'https://calmradio.com/en/relaxation', Icons.headphones),
            _Resource('Nature Sounds', 'Rain, ocean, forest sounds', 'https://www.noisli.com', Icons.headphones),
            _Resource('Brain.fm', 'Music for focus & relaxation', 'https://www.brain.fm', Icons.headphones),
          ]),
          const SizedBox(height: 14),

          // ── Videos ──
          _Section(title: 'Wellbeing Videos', icon: Icons.play_circle, color: kWarning, resources: const [
            _Resource('Beyond Blue — Anxiety', 'Understanding anxiety', 'https://www.beyondblue.org.au/mental-health/anxiety', Icons.ondemand_video),
            _Resource('Black Dog Institute', 'Mental health videos & tools', 'https://www.blackdoginstitute.org.au/resources-support/wellbeing', Icons.ondemand_video),
            _Resource('This Way Up', 'Evidence-based online programs', 'https://thiswayup.org.au', Icons.ondemand_video),
            _Resource('MindSpot', 'Free online assessments & courses', 'https://mindspot.org.au', Icons.ondemand_video),
          ]),
          const SizedBox(height: 14),

          // ── Sleep ──
          _Section(title: 'Sleep Hygiene', icon: Icons.bedtime, color: const Color(0xFF5C6BC0), resources: const [
            _Resource('Sleep Foundation', 'Sleep tips & science', 'https://www.sleepfoundation.org/sleep-hygiene', Icons.article),
            _Resource('Sleep Health Foundation (AU)', 'Australian sleep resources', 'https://www.sleephealthfoundation.org.au', Icons.article),
            _Resource('Sleepcast by Headspace', 'Bedtime wind-down stories', 'https://www.headspace.com/sleep/sleepcasts', Icons.nightlight),
          ]),
          const SizedBox(height: 14),

          // ── Physical Activity ──
          _Section(title: 'Gentle Movement', icon: Icons.directions_walk, color: kSuccess, resources: const [
            _Resource('Yoga with Adriene', 'Free yoga for all levels', 'https://yogawithadriene.com', Icons.play_circle_outline),
            _Resource('Tai Chi for Health', 'Gentle movement for wellness', 'https://taichiforhealthinstitute.org', Icons.play_circle_outline),
            _Resource('Body Scan Meditation', 'Progressive muscle relaxation', 'https://www.mindful.org/beginners-body-scan-meditation', Icons.self_improvement),
          ]),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _Resource {
  final String title, subtitle, url;
  final IconData icon;
  const _Resource(this.title, this.subtitle, this.url, this.icon);
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Resource> resources;
  const _Section({required this.title, required this.icon, required this.color, required this.resources});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 8),
      ...resources.map((r) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kDivider)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final uri = Uri.parse(r.url);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(r.icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
                Text(r.subtitle, style: TextStyle(fontSize: 10, color: kTextLight)),
              ])),
              Icon(Icons.open_in_new, size: 14, color: kTextLight),
            ]),
          ),
        ),
      )),
    ]);
  }
}
