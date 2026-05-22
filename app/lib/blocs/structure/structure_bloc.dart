import 'dart:async';
import 'package:equatable/equatable.dart';
import "package:flutter_bloc/flutter_bloc.dart";
import '../experiment/experiment_bloc.dart';

part "structure_event.dart";
part "structure_state.dart";

class StructureBloc extends Bloc<StructureEvent, StructureState> {
  final ExperimentBloc _experimentBloc;
  late final StreamSubscription<ExperimentState> _experimentSubscription;

  StructureBloc({required ExperimentBloc experimentBloc})
      : _experimentBloc = experimentBloc, super(const StructureInitial()) {
    on<StructureLoadRequested>(_onLoadRequested);
    on<ResidueSelected>(_onResidueSelected);
    on<ViewStructure>(_onViewStructure);
    on<MutationsUpdated>(_onMutationsUpdated);

    _experimentSubscription = _experimentBloc.stream.listen((experimentState) {
      if (experimentState is ExperimentActive) {
        add(MutationsUpdated(mutations: experimentState.currentMutations));
      }

      if (experimentState is ExperimentFinished) {
        add(const ViewStructure());
      }
    });
  }

  void _onLoadRequested(StructureLoadRequested event, Emitter<StructureState> emit) {
    emit(StructureReady(highlightedMutations: const [], pdbData: event.pdbData));
  }

  void _onResidueSelected(ResidueSelected event, Emitter<StructureState> emit) {
    final current = state;
    if (current is! StructureReady) return;

    if (current.selectedPosition == event.position) {
      emit(current.copyWith(clearSelection: true));
    } else {
      emit(current.copyWith(selectedPosition: event.position));
    }
  }

  void _onViewStructure(ViewStructure event, Emitter<StructureState> emit) {
    final current = state;
    if (current is! StructureReady) return;
    emit(current.copyWith(highlightedMutations: [], clearSelection: true));
  }

  void _onMutationsUpdated(MutationsUpdated event, Emitter<StructureState> emit) {
    final current = state;
    if (current is! StructureReady) return;
    emit(current.copyWith(highlightedMutations: event.mutations));
  }

  @override
  Future<void> close() {
    _experimentSubscription.cancel();
    return super.close();
  }
}