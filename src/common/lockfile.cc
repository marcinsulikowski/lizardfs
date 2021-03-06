#include "common/platform.h"
#include "common/lockfile.h"

#include <unistd.h>
#include <boost/filesystem.hpp>

#include "common/cwrap.h"
#include "common/exceptions.h"

Lockfile::Lockfile(const std::string& name)
		: name_(name), lock_(), locked_(false) {
}

Lockfile::~Lockfile() {
}

void Lockfile::lock(StaleLock staleLock) {
	bool existed = boost::filesystem::exists(name_);
	FileDescriptor fd(::open(name_.c_str(), O_CREAT | O_RDWR, 0644));
	fd.close();
	if (existed && (staleLock == StaleLock::kReject)) {
		throw LockfileException("Stale lockfile exists.", LockfileException::Reason::kStaleLock);
	}
	try {
		lock_ = boost::interprocess::file_lock(name_.c_str());
		locked_ = lock_.try_lock();
	} catch (const std::exception& e) {
		throw FilesystemException("Locking: " + name_ + ": " + e.what());
	}
	if (!locked_) {
		throw LockfileException(name_ + " is already locked!", LockfileException::Reason::kAlreadyLocked);
	}
	locked_ = true;
}

void Lockfile::unlock() {
	try {
		lock_.unlock();
		boost::filesystem::remove(name_);
	} catch (const std::exception& e) {
		throw FilesystemException("Unlocking: " + name_ + ": " + e.what());
	}
	locked_ = false;
}

bool Lockfile::isLocked() const {
	return locked_;
}

