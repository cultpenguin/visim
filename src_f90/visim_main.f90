!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! VISIM - Volume Integration SIMulation                               %
! Modernized to Fortran 90 - 2026                                     %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!-----------------------------------------------------------------------
!
!                Volume Integration SIMulation
!                ******************************
!
! The program is executed by specifying the parameter file as a
! command-line argument:
!   visim_f90 visim.par
!
! Or with no command-line arguments, in which case the user will be
! prompted for the parameter file name.
!
! The output file will be a GEOEAS file containing the simulated values.
! The file is ordered by x, y, z, and then simulation (i.e., x cycles
! fastest, then y, then z, then simulation number).
!
!-----------------------------------------------------------------------

program visim_main
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_kriging_mod
  use visim_search_mod
  use visim_histogram_mod
  use visim_random_mod
  use visim_allocate
  use visim_readpar_v2
  implicit none

  ! Local variables for dimension requirements (temporary holders)
  integer :: maxdat, maxvols, maxdinvol
  integer :: maxnod, maxsam, maxnst
  integer :: maxctx, maxcty, maxctz
  integer :: maxsbx_local, maxsby_local, maxsbz_local
  integer :: maxquan, maxmvlook, maxref, maxcat
  integer :: ierr

  write(*,*)
  write(*,*) '************************************************************'
  write(*,*) '*                                                          *'
  write(*,*) '*              VISIM - Fortran 90 Version                  *'
  write(*,*) '*      Volume Integration SIMulation with Dynamic          *'
  write(*,*) '*              Memory Allocation                           *'
  write(*,*) '*                                                          *'
  write(*,'(A,F5.2,A)') ' *              Version ', VERSION, '                                 *'
  write(*,*) '*                                                          *'
  write(*,*) '************************************************************'
  write(*,*)

  !=====================================================================
  ! PHASE 1: Read parameter file to determine dimension requirements
  !=====================================================================

  write(*,*) '======================================================='
  write(*,*) 'PHASE 1: Determining dimension requirements'
  write(*,*) '======================================================='
  write(*,*)

  call readparm_get_dimensions(maxdat, maxvols, maxdinvol, &
                                maxnod, maxsam, maxnst, &
                                maxctx, maxcty, maxctz, &
                                maxsbx_local, maxsby_local, maxsbz_local, &
                                maxquan, maxmvlook, maxref, maxcat)

  !=====================================================================
  ! PHASE 2: Allocate all arrays based on dimension requirements
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 2: Allocating dynamic arrays'
  write(*,*) '======================================================='

  call allocate_all_arrays(maxdat, maxvols, maxdinvol, &
                            maxnod, maxsam, maxnst, &
                            maxctx, maxcty, maxctz, &
                            maxsbx_local, maxsby_local, maxsbz_local, &
                            maxquan, maxmvlook, maxref, maxcat, &
                            nx, ny, nz, ierr)

  if (ierr /= 0) then
    write(*,*) 'FATAL ERROR: Memory allocation failed with code ', ierr
    write(*,*) 'Terminating program.'
    stop 1
  end if

  !=====================================================================
  ! PHASE 3: Read parameter file again and populate arrays
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 3: Reading parameters and data'
  write(*,*) '======================================================='
  write(*,*)

  call readparm_populate()

  !=====================================================================
  ! PHASE 4: Main simulation loop (placeholder for now)
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 4: Running simulation'
  write(*,*) '======================================================='
  write(*,*)

  ! NOTE: This is a placeholder. Full simulation requires:
  !   1. Creating conditional probability lookup table (if DSSIM)
  !   2. Setting up covariance lookup tables
  !   3. Opening output file
  !   4. Loop through realizations:
  !      - Generate random path
  !      - For each node: krige, simulate
  !   5. Writing results
  !   6. Saving covariance tables (if not read from file)

  write(*,*) 'NOTE: Full simulation loop not yet implemented.'
  write(*,*) '      This is a skeleton to demonstrate the framework.'
  write(*,*)
  write(*,'(A,I0,A)') '  Would simulate ', nsim, ' realization(s)'
  write(*,'(A,I0,A)') '  on ', nx*ny*nz, ' grid nodes'
  write(*,*)

  ! Placeholder for main simulation call
  ! do isim = 1, nsim
  !   call visim  ! Main simulation subroutine
  ! end do

  !=====================================================================
  ! PHASE 5: Cleanup and exit
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 5: Cleanup'
  write(*,*) '======================================================='
  write(*,*)

  call deallocate_all_arrays()

  write(*,*)
  write(*,*) '************************************************************'
  write(*,*) '*                                                          *'
  write(*,*) '*           VISIM F90 completed successfully!              *'
  write(*,*) '*                                                          *'
  write(*,*) '************************************************************'
  write(*,*)

  stop 0

end program visim_main
