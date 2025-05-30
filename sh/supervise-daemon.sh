# start / stop / status functions for supervise-daemon

# Copyright (c) 2016 The OpenRC Authors.
# See the Authors file at the top-level directory of this distribution and
# https://github.com/OpenRC/openrc/blob/HEAD/AUTHORS
#
# This file is part of OpenRC. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution and at https://github.com/OpenRC/openrc/blob/HEAD/LICENSE
# This file may not be copied, modified, propagated, or distributed
#    except according to the terms contained in the LICENSE file.

extra_commands="healthcheck unhealthy ${extra_commands}"

supervise_start()
{
	if [ -z "$command" ]; then
		ewarn "The command variable is undefined."
		ewarn "There is nothing for ${name:-$RC_SVCNAME} to start."
		return 1
	fi

	if [ -n "$ready" ]; then
		ewarn "Use 'notify=$ready' instead of 'ready=$ready'"
		notify="$ready"
	fi

	ebegin "Starting ${name:-$RC_SVCNAME}"
	# The eval call is necessary for cases like:
	# command_args="this \"is a\" test"
	# to work properly.
	eval supervise-daemon "${RC_SVCNAME}" --start \
		${retry:+--retry} $retry \
		${directory:+--chdir} $directory  \
		${chroot:+--chroot} $chroot \
		${input_file+--stdin} $input_file \
		${output_log+--stdout} ${output_log} \
		${error_log+--stderr} $error_log \
		${output_logger:+--stdout-logger \"$output_logger\"} \
		${error_logger:+--stderr-logger \"$error_logger\"} \
		${pidfile:+--pidfile} $pidfile \
		${respawn_delay:+--respawn-delay} $respawn_delay \
		${respawn_max:+--respawn-max} $respawn_max \
		${respawn_period:+--respawn-period} $respawn_period \
		${healthcheck_delay:+--healthcheck-delay} $healthcheck_delay \
		${healthcheck_timer:+--healthcheck-timer} $healthcheck_timer \
		${capabilities+--capabilities} "$capabilities" \
		${secbits:+--secbits} "$secbits" \
		${no_new_privs:+--no-new-privs} \
		${command_user+--user} $command_user \
		${umask+--umask} $umask \
		${notify+--notify} $notify \
		${supervise_daemon_args-${start_stop_daemon_args}} \
		$command \
		-- $command_args $command_args_foreground
	rc=$?
	if [ $rc = 0 ]; then
		[ -n "${chroot}" ] && service_set_value "chroot" "${chroot}"
		[ -n "${pidfile}" ] && service_set_value "pidfile" "${pidfile}"
	fi
	eend $rc "failed to start ${name:-$RC_SVCNAME}"
}

supervise_stop()
{
	local startchroot="$(service_get_value "chroot")"
	local startpidfile="$(service_get_value "pidfile")"
	chroot="${startchroot:-$chroot}"
	pidfile="${startpidfile:-$pidfile}"
	ebegin "Stopping ${name:-$RC_SVCNAME}"
	supervise-daemon "${RC_SVCNAME}" --stop \
		${pidfile:+--pidfile} $chroot$pidfile

	eend $? "Failed to stop ${name:-$RC_SVCNAME}"
}

_check_supervised()
{
	local child_pid start_time
	child_pid="$(service_get_value "child_pid")"
	start_time="$(service_get_value "start_time")"
	if [ -n "${child_pid}" ] && [ -n "${start_time}" ]; then
		return 1
	fi
	return 0
}

supervise_status()
{
	if service_stopping; then
		ewarn "status: stopping"
		return 4
	elif service_starting; then
		ewarn "status: starting"
		return 8
	elif service_inactive; then
		ewarn "status: inactive"
		return 16
	elif service_started; then
		if service_crashed; then
			if ! _check_supervised; then
				eerror "status: unsupervised"
				return 64
			fi
			eerror "status: crashed"
			return 32
		fi
		einfo "status: started"
		return 0
	else
		einfo "status: stopped"
		return 3
	fi
}

healthcheck()
{
	return 0
}

unhealthy()
{
	return 0
}
