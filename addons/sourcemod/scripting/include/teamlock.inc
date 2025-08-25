#if defined _teamlock_l4d2_survival_included_
  #endinput
#endif
#define _teamlock_l4d2_survival_included_


/**
 * @return        returns whether a client is whitelisted in the teamlock plugin
 */
native bool L4D2teamlock_IsClientWhitelisted(int client);


/**
 * @return        returns whether team lock is toggled on
 */
native bool L4D2teamlock_IsTeamlockEnabled();


/**
 * @return        returns 0 for teamlock enforced continuously, 1 for teamlock enforced when round in progress, and -1 for teamlock not in use
 */
native int L4D2teamlock_TeamlockMode();