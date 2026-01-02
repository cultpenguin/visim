real function simu(cmean1, cstdev1)
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! Converted to Fortran 90 - 2026                                      %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
!     This function draws from the local conditional distribution and returns
!     the value simu. The drawing depends on the type of local distribution
!     specified in idrawopt
!
!     ADAPTION : Thomas Mejer Hansen                DATE: August 2005-2015
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_histogram_mod
  use visim_random_mod
  implicit none

  ! Arguments
  real, intent(in) :: cmean1, cstdev1

  ! Local variables
  real*8 :: acorni, p
  real :: zt, drawfrom_condtab
  integer :: ierr

  ! External GSLIB functions
  external :: gauinv, drawfrom_condtab, acorni

  ! Get random number
  p = acorni(idum)

  if (idrawopt == 0) then
    ! Traditional Gaussian simulation
    call gauinv(dble(p), zt, ierr)
    simu = zt * cstdev1 + cmean1

  else if (idrawopt == 1) then
    ! Simulation matching a 1D marginal distribution
    simu = drawfrom_condtab(cmean1, cstdev1, real(p))

    if (simu < zmin) then
      if (idbg > 1) then
        write(*, *) 'VISIM_SIMU: ZMIN VIOLATION', zmin, simu
      end if
      simu = zmin
    end if

    if (simu > zmax) then
      if (idbg > 1) then
        write(*, *) 'VISIM_SIMU: ZMAX VIOLATION', zmax, simu
      end if
      simu = zmax
    end if

  else
    write(*, *) 'Error: drawing option larger than 1'
    write(*, *) 'No implementation for this option'
  end if

  return

end function simu
