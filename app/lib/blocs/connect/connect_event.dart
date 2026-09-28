part of "connect_bloc.dart";

sealed class ConnectEvent extends Equatable {
  const ConnectEvent();

  @override
  List<Object?> get props => [];
}

final class ConnectStarted extends ConnectEvent {
  const ConnectStarted();
}

final class ConnectRequested extends ConnectEvent {
  final String address;
  final String nickname;

  const ConnectRequested({required this.address, required this.nickname});

  @override
  List<Object?> get props => [address, nickname];
}
