return ListTile(
  title: Text(league.name),
  subtitle: Text('Max players: ${league.maxPlayers}'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeagueDetailPage(
          leagueId: league.id,
          leagueName: league.name,
        ),
      ),
    );
  },
);
