module nawia.network.epoll;

private import std.bitmanip;
private import core.sys.linux.epoll;
private import std.exception : errnoEnforce;
private import std.socket;

alias int EpollSocket;
alias int SetCreateFlags;
alias epoll_event Event;
alias int StandardSocket;



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
	;
	auto writeEvent = Event
		.init
		.writable( true )
	;
	writeln( SetCreateFlags.init
		.create
		.errnoEnforce( "Could not create epoll set" )
		.add( cast(int) sockets[0].handle, readEvent )
		.errnoEnforce( "Could not add reading socket to epoll set" )
		.add( cast(int) sockets[1].handle, writeEvent )
		.errnoEnforce( "Could not add writing socket to epoll set" )
		.remove( cast(int) sockets[0].handle, readEvent )
		.errnoEnforce( "Could not remove reading socket to epoll set" )
		.remove( cast(int) sockets[1].handle, writeEvent )
		.errnoEnforce( "Could not remove writing socket to epoll set" )
	);
}
