import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:percent_indicator/percent_indicator.dart';

class Mp extends StatefulWidget {
  const Mp({Key? key, required String title}) : super(key: key);

  @override
  _MpState createState() => _MpState();
}

class _MpState extends State<Mp> {
  String? selectedState;
  String? selectedConstituencies;
  String? selectedParty;
  bool isButtonDisabled = false;
  StreamController<QuerySnapshot> _updatePercentagesController =
      StreamController<QuerySnapshot>();

  @override
  void dispose() {
    _updatePercentagesController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('MP'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection("States").snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final states = snapshot.data!.docs
                        .map((doc) => doc['Name'] as String)
                        .toList();
                    return InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Select a state',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedState,
                        onChanged: (val) {
                          setState(() {
                            selectedState = val;
                            selectedConstituencies = null;
                            selectedParty = null;
                          });
                        },
                        items: states.map((state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  } else {
                    return CircularProgressIndicator();
                  }
                },
              ),
              SizedBox(height: 16.0),
              StreamBuilder<QuerySnapshot>(
                stream: selectedState != null
                    ? FirebaseFirestore.instance
                        .collection("MPConstituencies")
                        .where("State", isEqualTo: selectedState)
                        .snapshots()
                    : null, // Add a null check for selectedState
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final Constituenciess = snapshot.data!.docs
                        .map((doc) => doc['Name'] as String)
                        .toList();
                    Constituenciess.sort((a, b) => a.compareTo(b));
                    return InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Select a Constituencies',
                        border: OutlineInputBorder(),
                      ),
                      child: Scrollbar(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedConstituencies,
                          onChanged: (val) {
                            setState(() {
                              selectedConstituencies = val;
                            });
                          },
                          items: Constituenciess.map((Constituencies) {
                            return DropdownMenuItem<String>(
                              value: Constituencies,
                              child: Text(Constituencies),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  } else {
                    return SizedBox(); // Return an empty SizedBox while loading
                  }
                },
              ),
              SizedBox(height: 16.0),
              StreamBuilder<QuerySnapshot>(
                stream: selectedConstituencies != null
                    ? FirebaseFirestore.instance
                        .collection("PartyLists")
                        .where("State", isEqualTo: selectedState)
                        .snapshots()
                    : null, // Add a null check for selectedState
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final parties = snapshot.data!.docs
                        .map((doc) => doc['Name'] as String)
                        .toList();
                    parties.sort((a, b) => (a).compareTo(b));
                    return InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Select a Party',
                        border: OutlineInputBorder(),
                      ),
                      child: Scrollbar(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedParty,
                          onChanged: (val) {
                            setState(() {
                              selectedParty = val;
                            });
                          },
                          items: parties.map((party) {
                            return DropdownMenuItem<String>(
                              value: party,
                              child: Text(party),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  } else {
                    return SizedBox(); // Return an empty SizedBox while loading
                  }
                },
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: isButtonDisabled
                    ? null
                    : () async {
                        // Perform an action based on the selected state and city
                        if (selectedState != null &&
                            selectedConstituencies != null &&
                            selectedParty != null) {
                          CollectionReference collRef =
                              FirebaseFirestore.instance.collection('MP');
                          collRef.add({
                            'state': selectedState,
                            'constituency': selectedConstituencies,
                            'party': selectedParty,
                          });
                          setState(() {
                            isButtonDisabled = true; // Disable the button
                          });
                          final snackBar =
                              SnackBar(content: Text('Voted Sucessfully!'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          QuerySnapshot querySnapshot = await FirebaseFirestore
                              .instance
                              .collection("MP")
                              .where("state", isEqualTo: selectedState)
                              .where("constituency",
                                  isEqualTo: selectedConstituencies)
                              .get();
                          _updatePercentagesController.add(querySnapshot);
                        } else {
                          final snackBar =
                              SnackBar(content: Text('Select Every OPtion'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                      },
                child: Text('Vote'),
              ),
              SizedBox(height: 16.0),
              StreamBuilder(
                stream: _updatePercentagesController.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final partyPercentages = calculatePartyPercentages(
                        snapshot.data as QuerySnapshot);

                    // Display the party percentages for the selected state and constituency
                    return Column(
                      children: partyPercentages.entries.map((entry) {
                        final party = entry.key;
                        final percentage = entry.value;
                        return Padding(
                          padding: EdgeInsets.all(15.0),
                          child: LinearPercentIndicator(
                            width: 500.0,
                            animation: true,
                            lineHeight: 20.0,
                            animationDuration: 2500,
                            leading: Text(party),
                            percent: (percentage.truncateToDouble()) / 100,
                            center: Text(percentage.toStringAsFixed(2)),
                            // ignore: deprecated_member_use
                            linearStrokeCap: LinearStrokeCap.roundAll,
                            progressColor: Colors.green,
                          ),
                        );
                      }).toList(),
                    );
                  } else {
                    return SizedBox();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, double> calculatePartyPercentages(QuerySnapshot snapshot) {
  final Map<String, int> partyCounts = {};
  final Map<String, double> partyPercentages = {};

  // Count the number of votes for each party
  for (final doc in snapshot.docs) {
    final party = doc['party'] as String;
    partyCounts[party] = (partyCounts[party] ?? 0) + 1;
  }

  // Calculate the party percentages
  final totalVotes = snapshot.size;
  for (final entry in partyCounts.entries) {
    final party = entry.key;
    final count = entry.value;
    final percentage = (count / totalVotes) * 100;
    partyPercentages[party] = percentage;
  }

  return partyPercentages;
}
