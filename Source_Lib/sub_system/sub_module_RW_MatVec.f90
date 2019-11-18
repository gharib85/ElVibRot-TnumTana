!===========================================================================
!===========================================================================
!This file is part of Tnum-Tana.
!
!    Tnum-Tana is a free software: you can redistribute it and/or modify
!    it under the terms of the GNU Lesser General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    Tnum-Tana is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU Lesser General Public License for more details.
!
!    You should have received a copy of the GNU Lesser General Public License
!    along with ElVibRot.  If not, see <http://www.gnu.org/licenses/>.
!
!    Copyright 2015  David Lauvergnat
!      with contributions of Mamadou Ndong
!
!===========================================================================
!===========================================================================
MODULE mod_RW_MatVec
  USE mod_NumParameters, only: out_unitp, cmatio_format, rmatio_format, rkind, line_len
  USE mod_file, only : flush_perso
  IMPLICIT NONE

  PRIVATE

  INTERFACE Write_VecMat
    MODULE PROCEDURE Write_RMat,Write_CMat,Write_RVec,Write_CVec
  END INTERFACE
  INTERFACE Write_Mat
    MODULE PROCEDURE Write_RMat,Write_CMat
  END INTERFACE
  INTERFACE Write_Vec
    MODULE PROCEDURE Write_RVec,Write_CVec
  END INTERFACE
  INTERFACE Read_Mat
    MODULE PROCEDURE Read_RMat,Read_CMat
  END INTERFACE
  INTERFACE Read_Vec
    MODULE PROCEDURE Read_RVec,Read_CVec
  END INTERFACE

  !PRIVATE sub_Format_OF_Line
   PUBLIC :: Write_VecMat, Write_Mat, Write_Vec, Read_Mat, Read_Vec
   PUBLIC :: sub_ReadRV, sub_WriteRV

  CONTAINS

      !!@description: Defined a format to write a line of a matrix
      !!@param: TODO
      SUBROUTINE sub_Format_OF_Line(wformat,nb_line,max_col,cplx,       &
                                    Rformat,name_info)
       USE mod_string
       USE mod_MPI

       character (len=:), allocatable, intent(inout)  :: wformat
       integer,                        intent(in)     :: nb_line,max_col
       logical,                        intent(in)     :: cplx
       character (len=*), optional,    intent(in)     :: Rformat
       character (len=*), optional,    intent(in)     :: name_info


       character (len=:), allocatable :: NMatformat
       integer                        :: ilen

       IF (allocated(wformat)) deallocate(wformat)

       IF (present(name_info)) THEN
         wformat = String_TO_String('(2x,"' // trim(adjustl(name_info)) // ' ",')
       ELSE
         wformat = String_TO_String('(')
       END IF

       IF (present(Rformat)) THEN
         IF (len_trim(Rformat) > 10) THEN
           write(out_unitp,*) ' ERROR in sub_Format_OF_Line'
           write(out_unitp,*) ' The format (len_trim) in "Rformat" is too long',len_trim(Rformat)
           write(out_unitp,*) ' Rformat: ',Rformat
           STOP
         END IF
           IF (cplx) THEN
             NMatformat = String_TO_String("'('," // trim(adjustl(Rformat)) // &
                          ",' +i'," // trim(adjustl(Rformat)) // ",')'")
           ELSE
             NMatformat = String_TO_String(trim(adjustl(Rformat)))
           END IF
       ELSE
           IF (cplx) THEN
             NMatformat = String_TO_String(trim(adjustl(CMatIO_format)))
           ELSE
             NMatformat = String_TO_String(trim(adjustl(RMatIO_format)))
           END IF
       END IF

       IF (nb_line > 0) THEN

           !ilen = int(log10(real(nb_line,kind=Rkind)))+1
           ! ensure compatible with very small system in test
           ilen = MAX(int(log10(real(nb_line,kind=Rkind)))+1,2)
           write(*,*) 'max_col check:',max_col,ilen, ' from ',MPI_id
           
           wformat = String_TO_String(wformat // '1x,i' //              &
                       int_TO_char(ilen) // ',2x,' //                   &
                       int_TO_char(max_col) // '(' //                   &
                       trim(adjustl(NMatformat)) // ',1x))')


       ELSE

           wformat = String_TO_String(wformat //                         &
                       int_TO_char(max_col)   // '(' //                  &
                       trim(adjustl(NMatformat)) // ',1x))')


       END IF
       !write(6,*) 'NMatformat: ',NMatformat
       !write(6,*) 'wformat: ',wformat
       !flush(6)

       deallocate(NMatformat)

       !write(out_unitp,*) 'format?: ',trim(wformat)
      END SUBROUTINE sub_Format_OF_Line

      !!@description:  write a rectangular real or complex matrix, f(nl,nc),
      !!   with a specific format selected with sub_LineOFmatFormat
      !!@param: TODO
      SUBROUTINE Write_RMat(f,nio,nbcol1,Rformat,name_info)
        USE mod_MPI
        
        character (len=*), optional :: Rformat
        character (len=*), optional :: name_info

        integer, intent(in)         :: nio,nbcol1
        real(kind=Rkind), intent(in) :: f(:,:)

        integer         :: nl,nc
        integer i,j,nb,nbblocs,nfin,nbcol
        character (len=:), allocatable  :: wformat

        IF(MPI_id==0) THEN
          nl = size(f,dim=1)
          nc = size(f,dim=2)
          !write(out_unitp,*) 'nl,nc,nbcol',nl,nc,nbcol
          nbcol = nbcol1
          IF (nbcol > 10) nbcol=10
          nbblocs=int(nc/nbcol)
          IF (nbblocs*nbcol == nc) nbblocs=nbblocs-1

          IF (present(Rformat)) THEN
            IF (present(name_info)) THEN
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.FALSE.,Rformat,name_info)
            ELSE
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.FALSE.,Rformat=Rformat)
            END IF
          ELSE
            IF (present(name_info)) THEN
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.FALSE.,name_info=name_info)
            ELSE
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.FALSE.)
            END IF
          END IF

            DO nb=0,nbblocs-1
              DO j=1,nl
                write(nio,wformat) j,(f(j,i+nb*nbcol),i=1,nbcol)
              END DO
              IF (nl > 1 ) write(nio,*)
            END DO
            DO j=1,nl
              nfin=nc-nbcol*nbblocs
              write(nio,wformat) j,(f(j,i+nbcol*nbblocs),i=1,nfin)
            END DO

          deallocate(wformat)
        ENDIF ! for MPI_id==0

      END SUBROUTINE Write_RMat

      !!@description: TODO
      !!@param: TODO
      SUBROUTINE Write_CMat(f,nio,nbcol1,Rformat,name_info)
        USE mod_MPI
        
        character (len=*), optional     :: Rformat
        character (len=*), optional     :: name_info

        integer, intent(in)             :: nio,nbcol1
        complex(kind=Rkind), intent(in) :: f(:,:)

        integer         :: nl,nc
        integer i,j,nb,nbblocs,nfin,nbcol
        character (len=:), allocatable  :: wformat

        IF(MPI_id==0) THEN 
          nl = size(f,dim=1)
          nc = size(f,dim=2)
          !write(out_unitp,*) 'nl,nc,nbcol',nl,nc,nbcol
          nbcol = nbcol1
          IF (nbcol > 10) nbcol=10
          nbblocs=int(nc/nbcol)
          IF (nbblocs*nbcol == nc) nbblocs=nbblocs-1

          IF (present(Rformat)) THEN
            IF (present(name_info)) THEN
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.TRUE.,Rformat,name_info)
            ELSE
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.TRUE.,Rformat=Rformat)
            END IF
          ELSE
            IF (present(name_info)) THEN
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.TRUE.,name_info=name_info)
            ELSE
              CALL sub_Format_OF_Line(wformat,nl,nbcol,.TRUE.)
            END IF
          END IF


          DO nb=0,nbblocs-1
            DO j=1,nl
              write(nio,wformat) j,(f(j,i+nb*nbcol),i=1,nbcol)
            END DO
            IF (nl > 1 ) write(nio,*)
          END DO
          DO j=1,nl
            nfin=nc-nbcol*nbblocs
            write(nio,wformat) j,(f(j,i+nbcol*nbblocs),i=1,nfin)
          END DO
 
          deallocate(wformat)
        ENDIF ! for MPI_id==0  
          
      END SUBROUTINE Write_CMat

      !!@description: TODO
      !!@param: TODO
      SUBROUTINE Write_RVec(l,nio,nbcol1,Rformat,name_info)
      	 USE mod_MPI

         character (len=*), optional  :: Rformat
         character (len=*), optional  :: name_info

         integer, intent(in)          :: nio,nbcol1
         real(kind=Rkind), intent(in) :: l(:)

         integer           :: n,i,nb,nbblocs,nfin,nbcol
         character (len=:), allocatable  :: wformat

         IF(MPI_id==0) THEN
           n = size(l)
           !write(out_unitp,*) 'n,nbcol',n,nbcol
           nbcol = nbcol1
           IF (nbcol > 10) nbcol=10
           nbblocs=int(n/nbcol)
           IF (nbblocs*nbcol == n) nbblocs=nbblocs-1


           IF (present(Rformat)) THEN
             IF (present(name_info)) THEN
               CALL sub_Format_OF_Line(wformat,0,nbcol,.FALSE.,Rformat,name_info)
             ELSE
               CALL sub_Format_OF_Line(wformat,0,nbcol,.FALSE.,Rformat=Rformat)
             END IF
           ELSE
             IF (present(name_info)) THEN
               CALL sub_Format_OF_Line(wformat,0,nbcol,.FALSE.,name_info=name_info)
             ELSE
               CALL sub_Format_OF_Line(wformat,0,nbcol,.FALSE.)
             END IF
           END IF

           DO nb=0,nbblocs-1
             write(nio,wformat) (l(i+nb*nbcol),i=1,nbcol)
           END DO
           nfin=n-nbcol*nbblocs
           write(nio,wformat) (l(i+nbcol*nbblocs),i=1,nfin)

           deallocate(wformat)
        ENDIF ! for MPI_id==0
      END SUBROUTINE Write_RVec

      !!@description: TODO
      !!@param: TODO
      SUBROUTINE Write_CVec(l,nio,nbcol1,Rformat,name_info)
        USE mod_MPI

        character (len=*), optional     :: Rformat
        character (len=*), optional     :: name_info

        integer, intent(in)             :: nio,nbcol1
        complex(kind=Rkind), intent(in) :: l(:)

        integer           :: n,i,nb,nbblocs,nfin,nbcol
        character (len=:), allocatable  :: wformat

        IF(MPI_id==0) THEN
          n = size(l)
          !write(out_unitp,*) 'n,nbcol',n,nbcol
          nbcol = nbcol1
          IF (nbcol > 10) nbcol=10
          nbblocs=int(n/nbcol)
          IF (nbblocs*nbcol == n) nbblocs=nbblocs-1

          IF (present(Rformat)) THEN
            IF (present(name_info)) THEN
              CALL sub_Format_OF_Line(wformat,0,nbcol,.TRUE.,Rformat,name_info)
            ELSE
              CALL sub_Format_OF_Line(wformat,0,nbcol,.TRUE.,Rformat=Rformat)
            END IF
          ELSE
            IF (present(name_info)) THEN
              CALL sub_Format_OF_Line(wformat,0,nbcol,.TRUE.,name_info=name_info)
            ELSE
              CALL sub_Format_OF_Line(wformat,0,nbcol,.TRUE.)
            END IF
          END IF

          DO nb=0,nbblocs-1
            write(nio,wformat) (l(i+nb*nbcol),i=1,nbcol)
          END DO
          nfin=n-nbcol*nbblocs
          write(nio,wformat) (l(i+nbcol*nbblocs),i=1,nfin)

          deallocate(wformat)
        ENDIF ! for MPI_id==0
      END SUBROUTINE Write_CVec


      SUBROUTINE Read_RMat(f,nio,nbcol,err)

         integer, intent(in)             :: nio,nbcol
         integer, intent(inout)          :: err

         real(kind=Rkind), intent(inout) :: f(:,:)

         integer i,j,jj,nb,nbblocs,nfin,nl,nc

         nl = size(f,dim=1)
         nc = size(f,dim=2)
!        write(out_unitp,*) 'nl,nc,nbcol',nl,nc,nbcol


         nbblocs=int(nc/nbcol)

         IF (nbblocs*nbcol == nc) nbblocs=nbblocs-1
         err = 0

         DO nb=0,nbblocs-1

             DO j=1,nl
               read(nio,*,IOSTAT=err) jj,(f(j,i+nb*nbcol),i=1,nbcol)
               IF (err /= 0) EXIT
             END DO

             IF (err /= 0) EXIT

             IF (nl > 1) read(nio,*,IOSTAT=err)
             IF (err /= 0) EXIT

         END DO

         IF (err == 0) THEN
           DO j=1,nl
             nfin=nc-nbcol*nbblocs
             read(nio,*,IOSTAT=err) jj,(f(j,i+nbcol*nbblocs),i=1,nfin)
             IF (err /= 0) EXIT
           END DO
         END IF

         IF (err /= 0) THEN
           CALL Write_RMat(f,out_unitp,nbcol)
           write(out_unitp,*) ' ERROR in Read_RMat'
           write(out_unitp,*) '  while reading a matrix'
           write(out_unitp,*) '  end of file or end of record'
           write(out_unitp,*) '  The matrix paramters: nl,nc,nbcol',nl,nc,nbcol
           write(out_unitp,*) ' Check your data !!'
         END IF

      END SUBROUTINE Read_RMat
      SUBROUTINE Read_CMat(f,nio,nbcol,err)

         integer, intent(in)                :: nio,nbcol
         complex(kind=Rkind), intent(inout) :: f(:,:)
         integer, intent(inout)             :: err

         integer i,j,jj,nb,nbblocs,nfin,nl,nc

         nl = size(f,dim=1)
         nc = size(f,dim=2)
!        write(out_unitp,*) 'nl,nc,nbcol',nl,nc,nbcol


         nbblocs=int(nc/nbcol)
         err = 0
         IF (nbblocs*nbcol == nc) nbblocs=nbblocs-1

         DO nb=0,nbblocs-1

             DO j=1,nl
               read(nio,*,IOSTAT=err) jj,(f(j,i+nb*nbcol),i=1,nbcol)
               IF (err /= 0) EXIT
             END DO

             IF (err /= 0) EXIT

             IF (nl > 1) read(nio,*,IOSTAT=err)
             IF (err /= 0) EXIT

         END DO

         IF (err == 0) THEN
           DO j=1,nl
             nfin=nc-nbcol*nbblocs
             read(nio,*,IOSTAT=err) jj,(f(j,i+nbcol*nbblocs),i=1,nfin)
             IF (err /= 0) EXIT
           END DO
         END IF

         IF (err /= 0) THEN
           CALL Write_CMat(f,out_unitp,nbcol)
           write(out_unitp,*) ' ERROR in Read_CMat'
           write(out_unitp,*) '  while reading a matrix'
           write(out_unitp,*) '  end of file or end of record'
           write(out_unitp,*) '  The matrix paramters: nl,nc,nbcol',nl,nc,nbcol
           write(out_unitp,*) ' Check your data !!'
         END IF

      END SUBROUTINE Read_CMat

!================================================================
! ++    read a vector in line
!================================================================
      SUBROUTINE Read_RVec(l,nio,nbcol,err)

         integer, intent(in)                :: nio,nbcol
         real(kind=Rkind), intent(inout)    :: l(:)
         integer, intent(inout)             :: err

         integer :: n,i,nb,nbblocs,nfin

         n = size(l,dim=1)
         nbblocs=int(n/nbcol)
         err = 0


         IF (nbblocs*nbcol == n) nbblocs=nbblocs-1

         DO nb=0,nbblocs-1
           read(nio,*,IOSTAT=err) (l(i+nb*nbcol),i=1,nbcol)
           IF (err /= 0) EXIT
         END DO

         nfin=n-nbcol*nbblocs
         read(nio,*,IOSTAT=err) (l(i+nbcol*nbblocs),i=1,nfin)

         IF (err /= 0) THEN
           write(out_unitp,*) ' ERROR in Read_RVec'
           write(out_unitp,*) '  while reading a vector'
           write(out_unitp,*) '  end of file or end of record'
           write(out_unitp,*) '  The vector paramters: n,nbcol',n,nbcol
           write(out_unitp,*) ' Check your data !!'
         END IF

      END SUBROUTINE Read_RVec
      SUBROUTINE Read_CVec(l,nio,nbcol,err)

         integer, intent(in)                :: nio,nbcol
         complex(kind=Rkind), intent(inout) :: l(:)
         integer, intent(inout)             :: err

         integer :: n,i,nb,nbblocs,nfin

         n = size(l,dim=1)
         nbblocs=int(n/nbcol)
         err = 0

         IF (nbblocs*nbcol == n) nbblocs=nbblocs-1

         DO nb=0,nbblocs-1
           read(nio,*,IOSTAT=err) (l(i+nb*nbcol),i=1,nbcol)
           IF (err /= 0) EXIT
         END DO

         nfin=n-nbcol*nbblocs
         read(nio,*,IOSTAT=err) (l(i+nbcol*nbblocs),i=1,nfin)

         IF (err /= 0) THEN
           write(out_unitp,*) ' ERROR in Read_CVec'
           write(out_unitp,*) '  while reading a vector'
           write(out_unitp,*) '  end of file or end of record'
           write(out_unitp,*) '  The vector paramters: n,nbcol',n,nbcol
           write(out_unitp,*) ' Check your data !!'
         END IF

      END SUBROUTINE Read_CVec


SUBROUTINE sub_ReadRV(RV,FileName_RV,lformatted,err_sub)
  USE mod_file
  USE mod_NumParameters
  USE mod_memory_NotPointer
  IMPLICIT NONE

  real (kind=Rkind), allocatable,  intent(inout)           :: RV(:)
  character (len=Line_len),        intent(in)              :: FileName_RV
  logical,                         intent(in)              :: lformatted
  integer,                         intent(inout), optional :: err_sub

  character (len=*),               parameter               :: Name_sub='sub_ReadRV'


  integer :: nio,error,err_file,nvec

!  !$OMP  CRITICAL (sub_ReadRV_CRIT)
  error = 0
  nvec  = 0

  !write(out_unitp,*) 'lformatted',lformatted
  !write(out_unitp,*) 'FileName_RV: ',FileName_RV


  CALL file_open2(FileName_RV,nio,lformatted=lformatted,old=.TRUE.,err_file=err_file)
  IF (err_file /= 0) THEN
    write(out_unitp,*) ' ERROR in ',Name_sub
    write(out_unitp,*) '   Problem with the file associated to RV'
    write(out_unitp,*) '   file name: ',FileName_RV
    write(out_unitp,*) '   err_file: ',err_file
    CALL flush_perso(out_unitp)
    error = 2
  ELSE
      IF (lformatted) THEN
        read(nio,*,iostat=err_file) nvec
      ELSE
        read(nio,iostat=err_file) nvec
      END IF
    IF (err_file /= 0 .OR. nvec < 1) THEN
      write(out_unitp,*) ' ERROR in ',Name_sub
      write(out_unitp,*) '   Error while reading nvec',nvec
      write(out_unitp,*) '   file name: ',FileName_RV
      CALL flush_perso(out_unitp)
      error = 3
      nvec = 0
    END IF
  END IF

  IF (error == 0) THEN
    CALL alloc_NParray(RV,(/ nvec /),'RV',name_sub)
    IF (lformatted) THEN
      read(nio,*,iostat=err_file) RV
    ELSE
      read(nio,iostat=err_file) RV
    END IF
    IF (err_file /= 0) THEN
      write(out_unitp,*) ' ERROR in ',Name_sub
      write(out_unitp,*) '   Error while reading RV'
      write(out_unitp,*) '   file name: ',FileName_RV
      CALL flush_perso(out_unitp)
      error = 4
    END IF
  END IF

  close(nio,iostat=err_file)

  IF (present(err_sub)) THEN
    err_sub = error
  ELSE
    STOP ' in sub_ReadRV'
  END IF
!  !$OMP  END CRITICAL (sub_ReadRV_CRIT)

END SUBROUTINE sub_ReadRV
SUBROUTINE sub_WriteRV(RV,FileName_RV,lformatted,err_sub)
  USE mod_file
  USE mod_NumParameters
  USE mod_memory_NotPointer
  IMPLICIT NONE

  real (kind=Rkind), allocatable,  intent(in)              :: RV(:)
  character (len=Line_len),        intent(in)              :: FileName_RV
  logical,                         intent(in)              :: lformatted
  integer,                         intent(inout), optional :: err_sub

  character (len=*),               parameter               :: Name_sub='sub_WriteRV'

  integer :: nio,error,err_file,nvec

!  !$OMP  CRITICAL (sub_WriteRV_CRIT)

  error = 0
  nvec  = size(RV)

  IF (nvec < 1) THEN
    error = 1
  ELSE
    CALL file_open2(FileName_RV,nio,lformatted=lformatted,old=.FALSE.,err_file=err_file)
    IF (err_file /= 0) THEN
      write(out_unitp,*) ' ERROR in ',Name_sub
      write(out_unitp,*) '   Problem with the file associated to RV'
      write(out_unitp,*) '   file name: ',FileName_RV
      write(out_unitp,*) '   err_file: ',err_file
      CALL flush_perso(out_unitp)
      error = 2
    ELSE
      IF (lformatted) THEN
        write(nio,*,iostat=err_file) nvec
      ELSE
        write(nio,iostat=err_file) nvec
      END IF
      IF (err_file /= 0 .OR. nvec < 1) THEN
        write(out_unitp,*) ' ERROR in ',Name_sub
        write(out_unitp,*) '   Error while writing nvec',nvec
        write(out_unitp,*) '   file name: ',FileName_RV
        CALL flush_perso(out_unitp)
        error = 3
        nvec = 0
      ELSE
        IF (lformatted) THEN
          write(nio,*,iostat=err_file) RV
        ELSE
          write(nio,iostat=err_file) RV
        END IF
        IF (err_file /= 0) THEN
          write(out_unitp,*) ' ERROR in ',Name_sub
          write(out_unitp,*) '   Error while writing Rvec'
          write(out_unitp,*) '   file name: ',FileName_RV
          CALL flush_perso(out_unitp)
          error = 4
        END IF
      END IF
    END IF
  END IF

  close(nio,iostat=err_file)

  IF (present(err_sub)) THEN
    err_sub = error
  ELSE
    STOP ' in sub_WriteRV'
  END IF

!  !$OMP  END CRITICAL (sub_WriteRV_CRIT)


END SUBROUTINE sub_WriteRV

END MODULE mod_RW_MatVec

