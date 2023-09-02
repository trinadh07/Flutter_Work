import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/percent_indicator.dart';

class Cm extends StatefulWidget {
  const Cm({Key? key, required String title}) : super(key: key);

  @override
  _Cm createState() => _Cm();
}

class _Cm extends State<Cm> {
  String? selectedState;
  String? selectedCandidate;
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
        title: Text('CM'),
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
                        .collection("CMCandidate")
                        .where("State", isEqualTo: selectedState)
                        .snapshots()
                    : null,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final documents = snapshot.data!.docs;
                    return Column(
                      children: documents.map((doc) {
                        final val = doc["Name"];
                        final label = doc["Name"];
                        return RadioListTile(
                          value: val,
                          groupValue: selectedCandidate,
                          onChanged: (value) {
                            setState(() {
                              selectedCandidate = value;
                            });
                          },
                          title: Text(label),
                        );
                      }).toList(),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  return SizedBox();
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
                        // Perform an action based on the selected state, district, constituency, and party
                        if (selectedState != null &&
                            selectedCandidate != null) {
                          CollectionReference collRef =
                              FirebaseFirestore.instance.collection('CM');
                          collRef.add({
                            'Name': selectedCandidate,
                          });
                          setState(() {
                            isButtonDisabled = true; // Disable the button
                          });
                          final snackBar =
                              SnackBar(content: Text('Voted Successfully!'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);

                          // Retrieve the updated data and trigger recalculation of party percentages
                          QuerySnapshot querySnapshot = await FirebaseFirestore
                              .instance
                              .collection("CM")
                              .get();
                          _updatePercentagesController.add(querySnapshot);
                        } else {
                          final snackBar =
                              SnackBar(content: Text('Select Every Option'));
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
                    final candidatePercentages = calculateCandidatePercentages(
                        snapshot.data as QuerySnapshot);

                    // Display the party percentages for the selected state and constituency
                    return Column(
                      children: candidatePercentages.entries.map((entry) {
                        final name = entry.key;
                        final percentage = entry.value;
                        return Padding(
                          padding: EdgeInsets.all(15.0),
                          child: LinearPercentIndicator(
                            width: 500.0,
                            animation: true,
                            lineHeight: 20.0,
                            animationDuration: 2500,
                            leading: Text(name),
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

Map<String, double> calculateCandidatePercentages(QuerySnapshot snapshot) {
  final Map<String, int> CandidateCounts = {};
  final Map<String, double> CandidatePercentages = {};

  // Count the number of votes for each party
  for (final doc in snapshot.docs) {
    final name = doc['Name'] as String;
    CandidateCounts[name] = (CandidateCounts[name] ?? 0) + 1;
  }

  // Calculate the party percentages
  final totalVotes = snapshot.size;
  for (final entry in CandidateCounts.entries) {
    final party = entry.key;
    final count = entry.value;
    final percentage = (count / totalVotes) * 100;
    CandidatePercentages[party] = percentage;
  }

  return CandidatePercentages;
}
