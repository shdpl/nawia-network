module nawia.network.epoll;

private import std.bitmanip;
private import core.sys.linux.epoll;
private import std.exception : errnoEnforce;
private import std.socket;
private import std.conv;

alias int EpollSocket;
alias int SetCreateFlags;
alias epoll_event Event;
alias int StandardSocket;
alias to!int toInt;



SetCreateFlags closeOnExecveSet( SetCreateFlags flags, bool value )
{
	if( value )
	{
		flags |= EPOLL_CLOEXEC;
	}
	else
	{
		flags &= ~EPOLL_CLOEXEC;
	}
	return flags;
}
bool closeOnExecveGet( SetCreateFlags flags )
{
	return (flags & EPOLL_CLOEXEC) > 0;
}
SetCreateFlags closeOnExecveSave( SetCreateFlags flags, bool value )
{
	value = closeOnExecveGet( flags );
	return flags;
}

EpollSocket create( SetCreateFlags flags )
{
	auto ret = epoll_create1( flags );
	return ret;
}

EpollSocket add( EpollSocket set, StandardSocket socket, ref Event event )
{
	auto ret = epoll_ctl( set, EPOLL_CTL_ADD, socket, &event );
	return ret==0 ? set : ret;
}

EpollSocket remove( EpollSocket set, StandardSocket socket, ref Event event )
{
	auto ret = epoll_ctl( set, EPOLL_CTL_DEL, socket, &event );
	return ret==0 ? set : ret;
}

EpollSocket modify( EpollSocket set, StandardSocket socket, ref Event event )
{
	auto ret = epoll_ctl( set, EPOLL_CTL_MOD, socket, &event );
	return ret==0 ? set : ret;
}

EpollSocket wait( EpollSocket set, ref Event event, int timeout )
{
	auto ret = epoll_wait( set, &event, 1, timeout );
	return ret==0 ? set : ret;
}

EpollSocket wait( EpollSocket set, Event[] events, int timeout, out Event[] result )
{
	auto ret = epoll_wait( set, events.ptr, toInt( events.length ), timeout );
	result = events[0..ret];
	return ret==0 ? set : ret;
}

Event readable( Event event, bool value )
{
	auto flag = EPOLLIN;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event readable( Event event, out bool value )
{
	value = event.events & EPOLLIN ? true : false;
	return event;
}

Event writable( Event event, bool value )
{
	auto flag = EPOLLOUT;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event writable( Event event, out bool value )
{
	value = event.events & EPOLLOUT ? true : false;
	return event;
}

Event readablePriority( Event event, bool value )
{
	auto flag = EPOLLPRI;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event readablePriority( Event event, out bool value )
{
	value = event.events & EPOLLPRI ? true : false;
	return event;
}

Event error( Event event, bool value )
{
	auto flag = EPOLLERR;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event disconnectGraceful( Event event, bool value )
{
	auto flag = EPOLLHUP;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event disconnectDrop( Event event, bool value )
{
	auto flag = EPOLLRDHUP;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event edgeTriggerred( Event event, bool value )
{
	auto flag = EPOLLET;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

Event oneShot( Event event, bool value )
{
	auto flag = EPOLLONESHOT;
	if( value )
	{
		event.events |= flag;
	}
	else
	{
		event.events &= ~flag;
	}
	return event;
}

void main()
{
	import std.stdio : writeln;
	auto sockets = socketPair();
	foreach( s; sockets ) s.blocking = false;
	scope(exit) foreach ( s; sockets ) s.close();
	auto readEvent = Event
		.init
		.readable( true )
		.edgeTriggerred( true )
	;
	auto writeEvent = Event
		.init
		.writable( true )
		.readable( true )
	;
	Event[] readOut;
	immutable ubyte[] data = [1,2,3,4];
	sockets[0].send( data );
	readEvent.data.fd = cast(int) sockets[1].handle;
	writeEvent.data.fd = cast(int) sockets[0].handle;
	writeln( [sockets[1].handle, sockets[0].handle] );
	writeln( [readEvent.data.fd,writeEvent.data.fd] );
	auto socketSet = SetCreateFlags.init
		.create
		.errnoEnforce( "Could not create epoll set" )
		.add( cast(int) sockets[1].handle, readEvent )
		.errnoEnforce( "Could not add reading socket to epoll set" )
		.add( cast(int) sockets[0].handle, writeEvent )
		.errnoEnforce( "Could not add writing socket to epoll set" )
		.wait( [readEvent,writeEvent], 0, readOut );
		.errnoEnforce( "Could wait for sockets" )
	;
	foreach( Event event; readOut )
	{
		bool r, w, p;
		event.readable( r ).writable( w ).readablePriority( p );
		writeln( "flags", [EPOLLIN, EPOLLOUT, EPOLLPRI, EPOLLERR, EPOLLRDHUP] );
		writeln( [r, w, p], [event.events, event.events&EPOLLIN], [event.events, event.events&EPOLLOUT], event.data.fd );
	}
	auto buf = new ubyte[data.length];
	sockets[1].receive(buf);
	socketSet
		.remove( cast(int) sockets[1].handle, readEvent )
		.errnoEnforce( "Could not remove reading socket to epoll set" )
		.remove( cast(int) sockets[0].handle, writeEvent )
		.errnoEnforce( "Could not remove writing socket to epoll set" )
	;
}
